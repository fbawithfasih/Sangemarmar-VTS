import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import {
  ICarrierAdapter, RateQuote, ShipmentRequest, ShipmentResult, TrackingResult,
} from './carrier.adapter';

const FEDEX_SERVICE_LABELS: Record<string, string> = {
  INTERNATIONAL_PRIORITY: 'FedEx International Priority',
  INTERNATIONAL_ECONOMY: 'FedEx International Economy',
  INTERNATIONAL_FIRST: 'FedEx International First',
  FEDEX_INTERNATIONAL_PRIORITY: 'FedEx International Priority',
  FEDEX_INTERNATIONAL_ECONOMY: 'FedEx International Economy',
};

const FEDEX_STATUS_MAP: Record<string, string> = {
  OC: 'LABEL_CREATED',
  PU: 'PICKED_UP',
  IT: 'IN_TRANSIT',
  OD: 'OUT_FOR_DELIVERY',
  DL: 'DELIVERED',
  DE: 'EXCEPTION',
};

const HS_CODE = '6802.91'; // Worked marble articles (Sangemarmar = marble)

@Injectable()
export class FedexAdapter implements ICarrierAdapter {
  private readonly logger = new Logger(FedexAdapter.name);
  private readonly http: AxiosInstance;
  private readonly accountNumber: string;
  private tokenCache: { token: string; expiresAt: number } | null = null;

  constructor(private readonly config: ConfigService) {
    const sandbox = config.get<string>('FEDEX_SANDBOX', 'true') === 'true';
    const baseURL = sandbox
      ? 'https://apis-sandbox.fedex.com'
      : 'https://apis.fedex.com';

    this.http = axios.create({ baseURL, timeout: 30000 });
    this.accountNumber = config.get<string>('FEDEX_ACCOUNT_NUMBER', '');
  }

  private async getToken(): Promise<string> {
    if (this.tokenCache && Date.now() < this.tokenCache.expiresAt) {
      return this.tokenCache.token;
    }

    const params = new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: this.config.get<string>('FEDEX_CLIENT_ID', ''),
      client_secret: this.config.get<string>('FEDEX_CLIENT_SECRET', ''),
    });

    const res = await this.http.post('/oauth/token', params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });

    this.tokenCache = {
      token: res.data.access_token,
      expiresAt: Date.now() + (res.data.expires_in - 60) * 1000,
    };
    return this.tokenCache.token;
  }

  async getRates(req: Omit<ShipmentRequest, 'carrier' | 'serviceCode'>): Promise<RateQuote[]> {
    const token = await this.getToken();
    const body = {
      accountNumber: { value: this.accountNumber },
      requestedShipment: {
        shipper: { address: { streetLines: [req.shipper.address], city: req.shipper.city, stateOrProvinceCode: req.shipper.state, postalCode: req.shipper.zip, countryCode: req.shipper.country } },
        recipient: { address: { streetLines: [req.recipient.address], city: req.recipient.city, stateOrProvinceCode: req.recipient.state, postalCode: req.recipient.zip, countryCode: req.recipient.country } },
        pickupType: 'DROPOFF_AT_FEDEX_LOCATION',
        shipDateStamp: req.shipDate,
        rateRequestType: ['ACCOUNT', 'LIST'],
        requestedPackageLineItems: [{
          weight: { units: 'KG', value: req.weightKg },
          ...(req.lengthCm && { dimensions: { length: req.lengthCm, width: req.widthCm || 10, height: req.heightCm || 10, units: 'CM' } }),
        }],
      },
    };

    const res = await this.http.post('/rate/v1/rates/quotes', body, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'X-locale': 'en_US' },
    });

    const rateReplyDetails: any[] = res.data?.output?.rateReplyDetails ?? [];
    const quotes: RateQuote[] = [];

    for (const detail of rateReplyDetails) {
      const serviceType: string = detail.serviceType;
      const ratedShipment = detail.ratedShipmentDetails?.[0];
      if (!ratedShipment) continue;

      const costUsd = parseFloat(ratedShipment.totalNetCharge ?? ratedShipment.totalNetFedExCharge ?? '0');
      const currency: string = ratedShipment.currency ?? 'USD';
      const transitDays: number | null = detail.commit?.transitDays?.minimumTransitTime != null
        ? parseInt(detail.commit.transitDays.minimumTransitTime)
        : null;
      const deliveryDate: string | null = detail.commit?.dateDetail?.deliveryTimestamp ?? null;

      quotes.push({
        carrier: 'FEDEX',
        serviceCode: serviceType,
        serviceLabel: FEDEX_SERVICE_LABELS[serviceType] ?? serviceType,
        transitDays,
        deliveryDate,
        costUsd,
        currency,
      });
    }

    return quotes;
  }

  async createShipment(req: ShipmentRequest): Promise<ShipmentResult> {
    const token = await this.getToken();
    const totalQty = 1;
    const body = {
      accountNumber: { value: this.accountNumber },
      requestedShipment: {
        shipper: {
          contact: { personName: req.shipper.name, phoneNumber: req.shipper.phone },
          address: { streetLines: [req.shipper.address], city: req.shipper.city, stateOrProvinceCode: req.shipper.state, postalCode: req.shipper.zip, countryCode: req.shipper.country },
        },
        recipients: [{
          contact: { personName: req.recipient.name, phoneNumber: req.recipient.phone, emailAddress: req.recipient.email },
          address: { streetLines: [req.recipient.address], city: req.recipient.city, stateOrProvinceCode: req.recipient.state, postalCode: req.recipient.zip, countryCode: req.recipient.country },
        }],
        serviceType: req.serviceCode,
        packagingType: 'YOUR_PACKAGING',
        pickupType: 'DROPOFF_AT_FEDEX_LOCATION',
        totalWeight: req.weightKg,
        shipDatestamp: req.shipDate,
        labelSpecification: {
          labelFormatType: 'COMMON2D',
          imageType: 'PDF',
          labelStockType: 'PAPER_4X6',
        },
        shippingChargesPayment: {
          paymentType: 'SENDER',
          payor: { responsibleParty: { accountNumber: { value: this.accountNumber } } },
        },
        customsClearanceDetail: {
          dutiesPayment: {
            paymentType: 'SENDER',
            payor: { responsibleParty: { accountNumber: { value: this.accountNumber } } },
          },
          customsValue: { currency: 'USD', amount: req.declaredValueUsd },
          commodities: [{
            description: req.contentsDescription,
            countryOfManufacture: 'IN',
            harmonizedCode: HS_CODE,
            name: req.contentsDescription,
            numberOfPieces: totalQty,
            quantity: totalQty,
            quantityUnits: 'PCS',
            unitPrice: { currency: 'USD', amount: req.declaredValueUsd },
            weight: { units: 'KG', value: req.weightKg },
          }],
        },
        requestedPackageLineItems: [{
          weight: { units: 'KG', value: req.weightKg },
          ...(req.lengthCm && { dimensions: { length: req.lengthCm, width: req.widthCm || 10, height: req.heightCm || 10, units: 'CM' } }),
          declaredValue: { currency: 'USD', amount: req.declaredValueUsd },
        }],
      },
    };

    const res = await this.http.post('/ship/v1/shipments', body, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'X-locale': 'en_US' },
    });

    const output = res.data?.output;
    if (!output?.transactionShipments?.[0]) {
      this.logger.error('FedEx shipment response missing transactionShipments', JSON.stringify(res.data));
      throw new BadRequestException('FedEx: shipment creation failed');
    }

    const shipment = output.transactionShipments[0];
    const trackingNumber: string = shipment.masterTrackingNumber;
    const piece = shipment.pieceResponses?.[0];
    const labelBase64: string = piece?.packageDocuments?.[0]?.encodedLabel ?? '';
    const estimatedDelivery: string | null = shipment.completedShipmentDetail?.operationalDetail?.deliveryDate ?? null;
    const costUsd = parseFloat(shipment.completedShipmentDetail?.shipmentRating?.actualRateDetails?.[0]?.totalNetCharge ?? '0');

    return { carrierShipmentId: shipment.shipmentId ?? trackingNumber, trackingNumber, labelBase64, estimatedDelivery, costUsd };
  }

  async trackShipment(trackingNumber: string): Promise<TrackingResult> {
    const token = await this.getToken();
    const body = {
      trackingInfo: [{ trackingNumberInfo: { trackingNumber } }],
      includeDetailedScans: true,
    };

    const res = await this.http.post('/track/v1/trackingnumbers', body, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'X-locale': 'en_US' },
    });

    const pkg = res.data?.output?.completeTrackResults?.[0]?.trackResults?.[0];
    if (!pkg) return { status: 'UNKNOWN', statusLabel: 'Unknown', estimatedDelivery: null, events: [] };

    const latestStatusCode: string = pkg.latestStatusDetail?.code ?? '';
    const status = FEDEX_STATUS_MAP[latestStatusCode] ?? 'IN_TRANSIT';
    const statusLabel: string = pkg.latestStatusDetail?.description ?? status;
    const estimatedDelivery: string | null = pkg.estimatedDeliveryTimeWindow?.window?.ends ?? null;

    const events = (pkg.scanEvents ?? []).map((e: any) => ({
      timestamp: e.date ?? '',
      description: e.eventDescription ?? '',
      location: [e.scanLocation?.city, e.scanLocation?.countryCode].filter(Boolean).join(', '),
    }));

    return { status, statusLabel, estimatedDelivery, events };
  }
}

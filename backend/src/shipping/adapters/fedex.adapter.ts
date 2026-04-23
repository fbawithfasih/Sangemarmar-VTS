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

    this.logger.log(`FedEx token obtained, expires_in=${res.data.expires_in}s`);
    this.tokenCache = {
      token: res.data.access_token,
      expiresAt: Date.now() + (res.data.expires_in - 60) * 1000,
    };
    return this.tokenCache.token;
  }

  private addr(address: string, city: string, state: string, zip: string, country: string) {
    // Normalize to 2-letter ISO (guard against "USA" / "IND" etc.)
    const iso = country.trim().toUpperCase().substring(0, 2);
    const needsState = ['US', 'CA', 'MX', 'IN'].includes(iso);
    return {
      streetLines: [address],
      city,
      postalCode: zip,
      countryCode: iso,
      ...(needsState && state ? { stateOrProvinceCode: state.substring(0, 2).toUpperCase() } : {}),
    };
  }

  async getRates(req: Omit<ShipmentRequest, 'carrier' | 'serviceCode'>): Promise<RateQuote[]> {
    const token = await this.getToken();
    const body = {
      accountNumber: { value: this.accountNumber },
      requestedShipment: {
        shipper: { address: this.addr(req.shipper.address, req.shipper.city, req.shipper.state, req.shipper.zip, req.shipper.country) },
        recipient: { address: this.addr(req.recipient.address, req.recipient.city, req.recipient.state, req.recipient.zip, req.recipient.country) },
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
      // Freight services require a separate freight account — skip them
      if (serviceType?.toUpperCase().includes('FREIGHT')) continue;
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
          address: this.addr(req.shipper.address, req.shipper.city, req.shipper.state, req.shipper.zip, req.shipper.country),
        },
        recipients: [{
          contact: { personName: req.recipient.name, phoneNumber: req.recipient.phone, emailAddress: req.recipient.email },
          address: this.addr(req.recipient.address, req.recipient.city, req.recipient.state, req.recipient.zip, req.recipient.country),
        }],
        serviceType: req.serviceCode,
        packagingType: 'YOUR_PACKAGING',
        pickupType: 'DROPOFF_AT_FEDEX_LOCATION',
        totalWeight: req.weightKg,
        totalPackageCount: 1,
        shipDatestamp: req.shipDate,
        labelResponseOptions: 'LABEL',
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
          sequenceNumber: 1,
          weight: { units: 'KG', value: req.weightKg },
          ...(req.lengthCm && { dimensions: { length: req.lengthCm, width: req.widthCm || 10, height: req.heightCm || 10, units: 'CM' } }),
          declaredValue: { currency: 'USD', amount: req.declaredValueUsd },
        }],
      },
    };

    let res: any;
    try {
      res = await this.http.post('/ship/v1/shipments', body, {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'X-locale': 'en_US' },
      });
    } catch (err: any) {
      const fedexErrors: any[] = err?.response?.data?.errors ?? [];
      const msg = fedexErrors.length
        ? fedexErrors.map((e: any) => {
            const base = e.message ?? e.code ?? 'Unknown error';
            const params: any[] = e.parameterList ?? [];
            const detail = params.map((p: any) => p.value ?? p.key).filter(Boolean).join(', ');
            return detail ? `${base}: ${detail}` : base;
          }).join('; ')
        : err?.message ?? 'FedEx booking request failed';
      this.logger.error(`FedEx createShipment error: ${msg}`, JSON.stringify(err?.response?.data ?? {}));
      throw new BadRequestException(`FedEx: ${msg}`);
    }

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

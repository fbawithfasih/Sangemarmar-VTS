import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import {
  ICarrierAdapter, RateQuote, ShipmentRequest, ShipmentResult, TrackingResult,
} from './carrier.adapter';

const DHL_STATUS_MAP: Record<string, string> = {
  'transit': 'IN_TRANSIT',
  'delivered': 'DELIVERED',
  'pickup': 'PICKED_UP',
  'out-for-delivery': 'OUT_FOR_DELIVERY',
  'exception': 'EXCEPTION',
};

const HS_CODE = '6802.91';

@Injectable()
export class DhlAdapter implements ICarrierAdapter {
  private readonly http: AxiosInstance;
  private readonly accountNumber: string;

  constructor(private readonly config: ConfigService) {
    const sandbox = config.get<string>('DHL_SANDBOX', 'true') === 'true';
    const baseURL = sandbox
      ? 'https://express.api.dhl.com/mydhlapi/test'
      : 'https://express.api.dhl.com/mydhlapi';

    const apiKey = config.get<string>('DHL_API_KEY', '');
    const apiSecret = config.get<string>('DHL_API_SECRET', '');
    const encoded = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');

    this.http = axios.create({
      baseURL,
      timeout: 30000,
      headers: { Authorization: `Basic ${encoded}` },
    });
    this.accountNumber = config.get<string>('DHL_ACCOUNT_NUMBER', '');
  }

  async getRates(req: Omit<ShipmentRequest, 'carrier' | 'serviceCode'>): Promise<RateQuote[]> {
    const params = {
      accountNumber: this.accountNumber,
      originCountryCode: req.shipper.country,
      originCityName: req.shipper.city,
      destinationCountryCode: req.recipient.country,
      destinationCityName: req.recipient.city,
      weight: req.weightKg,
      length: req.lengthCm ?? 10,
      width: req.widthCm ?? 10,
      height: req.heightCm ?? 10,
      plannedShippingDate: req.shipDate,
      isCustomsDeclarable: true,
      unitOfMeasurement: 'metric',
    };

    const res = await this.http.get('/rates', { params });
    const products: any[] = res.data?.products ?? [];

    return products.map((p) => ({
      carrier: 'DHL',
      serviceCode: p.productCode,
      serviceLabel: `DHL ${p.productName}`,
      transitDays: p.deliveryCapabilities?.totalTransitDays ?? null,
      deliveryDate: p.deliveryCapabilities?.estimatedDeliveryDateAndTime ?? null,
      costUsd: parseFloat(p.totalPrice?.[0]?.price ?? '0'),
      currency: p.totalPrice?.[0]?.priceCurrency ?? 'USD',
    }));
  }

  async createShipment(req: ShipmentRequest): Promise<ShipmentResult> {
    const body = {
      plannedShippingDateAndTime: `${req.shipDate}T10:00:00 GMT+05:30`,
      pickup: { isRequested: false },
      productCode: req.serviceCode,
      accounts: [{ typeCode: 'shipper', number: this.accountNumber }],
      outputImageProperties: { printerDPI: 300, encodingFormat: 'pdf', imageOptions: [{ typeCode: 'label', templateName: 'ECOM26_84_A4_001', isRequested: true }] },
      customerDetails: {
        shipperDetails: {
          postalAddress: { postalCode: req.shipper.zip, cityName: req.shipper.city, countryCode: req.shipper.country, addressLine1: req.shipper.address },
          contactInformation: { fullName: req.shipper.name, phone: req.shipper.phone },
          typeCode: 'business',
        },
        receiverDetails: {
          postalAddress: { postalCode: req.recipient.zip, cityName: req.recipient.city, countryCode: req.recipient.country, addressLine1: req.recipient.address },
          contactInformation: { fullName: req.recipient.name, phone: req.recipient.phone, email: req.recipient.email },
          typeCode: 'private',
        },
      },
      content: {
        packages: [{
          weight: req.weightKg,
          dimensions: { length: req.lengthCm ?? 10, width: req.widthCm ?? 10, height: req.heightCm ?? 10 },
        }],
        isCustomsDeclarable: true,
        declaredValue: req.declaredValueUsd,
        declaredValueCurrency: 'USD',
        description: req.contentsDescription,
        incoterm: 'DAP',
        unitOfMeasurement: 'metric',
        exportDeclaration: {
          lineItems: [{
            number: 1,
            description: req.contentsDescription,
            price: req.declaredValueUsd,
            priceCurrency: 'USD',
            quantity: { value: 1, unitOfMeasurement: 'PCS' },
            commodityCodes: [{ typeCode: 'outbound', value: HS_CODE }],
            exportReasonType: 'permanent',
            manufacturerCountry: 'IN',
            weight: { netValue: req.weightKg, grossValue: req.weightKg, unitOfMeasurement: 'kg' },
          }],
          invoice: { date: req.shipDate, number: `INV-${Date.now()}`, signatureName: req.shipper.name },
          exportReason: 'permanent',
        },
      },
    };

    const res = await this.http.post('/shipments', body);
    const data = res.data;

    if (!data?.shipmentTrackingNumber) {
      throw new BadRequestException('DHL: shipment creation failed');
    }

    const labelBase64: string = data.documents?.[0]?.content ?? '';
    const trackingNumber: string = data.shipmentTrackingNumber;

    return {
      carrierShipmentId: data.dispatchConfirmationNumber ?? trackingNumber,
      trackingNumber,
      labelBase64,
      estimatedDelivery: data.estimatedDeliveryDate ?? null,
      costUsd: parseFloat(data.shipmentCharges?.[0]?.price ?? '0'),
    };
  }

  async trackShipment(trackingNumber: string): Promise<TrackingResult> {
    const res = await this.http.get('/tracking', { params: { trackingNumber } });
    const shipment = res.data?.shipments?.[0];
    if (!shipment) return { status: 'UNKNOWN', statusLabel: 'Unknown', estimatedDelivery: null, events: [] };

    const rawStatus: string = shipment.status ?? '';
    const status = DHL_STATUS_MAP[rawStatus.toLowerCase()] ?? 'IN_TRANSIT';

    const events = (shipment.events ?? []).map((e: any) => ({
      timestamp: e.timestamp ?? '',
      description: e.description ?? '',
      location: [e.location?.address?.addressLocality, e.location?.address?.countryCode].filter(Boolean).join(', '),
    }));

    return {
      status,
      statusLabel: shipment.statusCode ?? status,
      estimatedDelivery: shipment.estimatedTimeOfDelivery ?? null,
      events,
    };
  }
}

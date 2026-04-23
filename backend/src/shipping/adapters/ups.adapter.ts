import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import {
  ICarrierAdapter, RateQuote, ShipmentRequest, ShipmentResult, TrackingResult,
} from './carrier.adapter';

const UPS_SERVICE_LABELS: Record<string, string> = {
  '07': 'UPS Worldwide Express',
  '08': 'UPS Worldwide Expedited',
  '54': 'UPS Worldwide Express Plus',
  '65': 'UPS Worldwide Saver',
  '96': 'UPS Worldwide Economy',
};

const UPS_STATUS_MAP: Record<string, string> = {
  'M': 'LABEL_CREATED',
  'P': 'PICKED_UP',
  'I': 'IN_TRANSIT',
  'O': 'OUT_FOR_DELIVERY',
  'D': 'DELIVERED',
  'X': 'EXCEPTION',
};

const HS_CODE = '6802.91';

@Injectable()
export class UpsAdapter implements ICarrierAdapter {
  private readonly http: AxiosInstance;
  private readonly authHttp: AxiosInstance;
  private readonly accountNumber: string;
  private tokenCache: { token: string; expiresAt: number } | null = null;

  constructor(private readonly config: ConfigService) {
    const sandbox = config.get<string>('UPS_SANDBOX', 'true') === 'true';
    // API calls use /api prefix; OAuth does NOT — separate instances required
    const apiBase = sandbox ? 'https://wwwcie.ups.com/api' : 'https://onlinetools.ups.com/api';
    const authBase = sandbox ? 'https://wwwcie.ups.com' : 'https://onlinetools.ups.com';

    this.http = axios.create({ baseURL: apiBase, timeout: 30000 });
    this.authHttp = axios.create({ baseURL: authBase, timeout: 30000 });
    this.accountNumber = config.get<string>('UPS_ACCOUNT_NUMBER', '');
  }

  private async getToken(): Promise<string> {
    if (this.tokenCache && Date.now() < this.tokenCache.expiresAt) {
      return this.tokenCache.token;
    }

    const clientId = this.config.get<string>('UPS_CLIENT_ID', '');
    const clientSecret = this.config.get<string>('UPS_CLIENT_SECRET', '');
    const encoded = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const params = new URLSearchParams({ grant_type: 'client_credentials' });

    const res = await this.authHttp.post('/security/v1/oauth/token', params.toString(), {
      headers: {
        Authorization: `Basic ${encoded}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
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
      RateRequest: {
        Request: { TransactionReference: { CustomerContext: 'Rate Shop' } },
        Shipment: {
          Shipper: {
            Name: req.shipper.name,
            ShipperNumber: this.accountNumber,
            Address: { AddressLine: req.shipper.address, City: req.shipper.city, PostalCode: req.shipper.zip, CountryCode: req.shipper.country },
          },
          ShipTo: {
            Name: req.recipient.name,
            Address: { AddressLine: req.recipient.address, City: req.recipient.city, PostalCode: req.recipient.zip, CountryCode: req.recipient.country },
          },
          ShipFrom: {
            Name: req.shipper.name,
            Address: { AddressLine: req.shipper.address, City: req.shipper.city, PostalCode: req.shipper.zip, CountryCode: req.shipper.country },
          },
          Package: {
            PackagingType: { Code: '02' },
            PackageWeight: { UnitOfMeasurement: { Code: 'KGS' }, Weight: String(req.weightKg) },
            ...(req.lengthCm && {
              Dimensions: { UnitOfMeasurement: { Code: 'CM' }, Length: String(req.lengthCm), Width: String(req.widthCm ?? 10), Height: String(req.heightCm ?? 10) },
            }),
          },
        },
      },
    };

    const res = await this.http.post('/rating/v1/Shop', body, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    });

    const ratedShipments: any[] = res.data?.RateResponse?.RatedShipment ?? [];
    return ratedShipments.map((s) => {
      const code: string = s.Service?.Code ?? '';
      return {
        carrier: 'UPS',
        serviceCode: code,
        serviceLabel: UPS_SERVICE_LABELS[code] ?? `UPS Service ${code}`,
        transitDays: s.GuaranteedDaysToDelivery ? parseInt(s.GuaranteedDaysToDelivery) : null,
        deliveryDate: s.RatedShipmentAlert?.DeliveryDate ?? null,
        costUsd: parseFloat(s.TotalCharges?.MonetaryValue ?? '0'),
        currency: s.TotalCharges?.CurrencyCode ?? 'USD',
      };
    });
  }

  async createShipment(req: ShipmentRequest): Promise<ShipmentResult> {
    const token = await this.getToken();
    const body = {
      ShipmentRequest: {
        Request: { SubVersion: '1801', RequestOption: 'nonvalidate', TransactionReference: { CustomerContext: '' } },
        Shipment: {
          Description: req.contentsDescription,
          Shipper: {
            Name: req.shipper.name,
            AttentionName: req.shipper.name,
            Phone: { Number: req.shipper.phone },
            ShipperNumber: this.accountNumber,
            Address: { AddressLine: req.shipper.address, City: req.shipper.city, StateProvinceCode: req.shipper.state, PostalCode: req.shipper.zip, CountryCode: req.shipper.country },
          },
          ShipTo: {
            Name: req.recipient.name,
            AttentionName: req.recipient.name,
            Phone: { Number: req.recipient.phone },
            EMailAddress: req.recipient.email,
            Address: { AddressLine: req.recipient.address, City: req.recipient.city, StateProvinceCode: req.recipient.state, PostalCode: req.recipient.zip, CountryCode: req.recipient.country },
          },
          ShipFrom: {
            Name: req.shipper.name,
            AttentionName: req.shipper.name,
            Phone: { Number: req.shipper.phone },
            Address: { AddressLine: req.shipper.address, City: req.shipper.city, StateProvinceCode: req.shipper.state, PostalCode: req.shipper.zip, CountryCode: req.shipper.country },
          },
          PaymentInformation: {
            ShipmentCharge: { Type: '01', BillShipper: { AccountNumber: this.accountNumber } },
          },
          Service: { Code: req.serviceCode },
          Package: {
            Packaging: { Code: '02' },
            PackageWeight: { UnitOfMeasurement: { Code: 'KGS' }, Weight: String(req.weightKg) },
            ...(req.lengthCm && {
              Dimensions: { UnitOfMeasurement: { Code: 'CM' }, Length: String(req.lengthCm), Width: String(req.widthCm ?? 10), Height: String(req.heightCm ?? 10) },
            }),
          },
          ShipmentServiceOptions: {
            InternationalForms: {
              FormType: ['01'],
              Product: [{
                Description: req.contentsDescription,
                Unit: { Number: '1', UnitOfMeasurement: { Code: 'PCS' }, Value: String(req.declaredValueUsd) },
                CommodityCode: HS_CODE,
                OriginCountryCode: 'IN',
              }],
              InvoiceDate: req.shipDate.replace(/-/g, ''),
              TermsOfShipment: 'DAP',
              CurrencyCode: 'USD',
              DeclarationStatement: 'I hereby certify that the information on this invoice is true and correct and the contents and value of this shipment is as stated above.',
            },
          },
        },
        LabelSpecification: { LabelImageFormat: { Code: 'PDF' }, HTTPUserAgent: 'Mozilla/4.5' },
      },
    };

    const res = await this.http.post('/shipments/v1/ship', body, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    });

    const result = res.data?.ShipmentResponse?.ShipmentResults;
    if (!result) throw new BadRequestException('UPS: shipment creation failed');

    const trackingNumber: string = result.ShipmentIdentificationNumber;
    const labelBase64: string = result.PackageResults?.ShippingLabel?.GraphicImage ?? '';
    const costUsd = parseFloat(result.ShipmentCharges?.TotalCharges?.MonetaryValue ?? '0');

    return {
      carrierShipmentId: trackingNumber,
      trackingNumber,
      labelBase64,
      estimatedDelivery: null,
      costUsd,
    };
  }

  async trackShipment(trackingNumber: string): Promise<TrackingResult> {
    const token = await this.getToken();
    const res = await this.http.get(`/track/v1/details/${trackingNumber}`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { locale: 'en_US', returnSignature: 'false' },
    });

    const pkg = res.data?.trackResponse?.shipment?.[0]?.package?.[0];
    if (!pkg) return { status: 'UNKNOWN', statusLabel: 'Unknown', estimatedDelivery: null, events: [] };

    const statusCode: string = pkg.currentStatus?.code ?? '';
    const status = UPS_STATUS_MAP[statusCode] ?? 'IN_TRANSIT';
    const statusLabel: string = pkg.currentStatus?.description ?? status;
    const estimatedDelivery: string | null = pkg.deliveryDate?.[0]?.date ?? null;

    const events = (pkg.activity ?? []).map((a: any) => ({
      timestamp: `${a.date ?? ''}T${a.time ?? ''}`,
      description: a.status?.description ?? '',
      location: [a.location?.address?.city, a.location?.address?.country].filter(Boolean).join(', '),
    }));

    return { status, statusLabel, estimatedDelivery, events };
  }
}

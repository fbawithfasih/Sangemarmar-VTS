export interface RateQuote {
  carrier: string;
  serviceCode: string;
  serviceLabel: string;
  transitDays: number | null;
  deliveryDate: string | null;
  costUsd: number;
  currency: string;
}

export interface ShipmentRequest {
  carrier: string;
  serviceCode: string;
  shipper: {
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    country: string;
    phone: string;
  };
  recipient: {
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    country: string;
    phone: string;
    email: string;
  };
  weightKg: number;
  lengthCm?: number;
  widthCm?: number;
  heightCm?: number;
  declaredValueUsd: number;
  contentsDescription: string;
  shipDate: string; // YYYY-MM-DD
}

export interface ShipmentResult {
  carrierShipmentId: string;
  trackingNumber: string;
  labelBase64: string;
  estimatedDelivery: string | null;
  costUsd: number;
}

export interface TrackingEvent {
  timestamp: string;
  description: string;
  location: string;
}

export interface TrackingResult {
  status: string;
  statusLabel: string;
  estimatedDelivery: string | null;
  events: TrackingEvent[];
}

export interface ICarrierAdapter {
  getRates(req: Omit<ShipmentRequest, 'carrier' | 'serviceCode'>): Promise<RateQuote[]>;
  createShipment(req: ShipmentRequest): Promise<ShipmentResult>;
  trackShipment(trackingNumber: string): Promise<TrackingResult>;
}

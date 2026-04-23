import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { Shipment } from './entities/shipment.entity';
import { FedexAdapter } from './adapters/fedex.adapter';
import { DhlAdapter } from './adapters/dhl.adapter';
import { UpsAdapter } from './adapters/ups.adapter';
import { ICarrierAdapter, RateQuote, ShipmentRequest } from './adapters/carrier.adapter';
import { GetRatesDto } from './dto/get-rates.dto';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { ShipmentFilterDto } from './dto/shipment-filter.dto';
import { BillingOrder } from '../billing/entities/billing-order.entity';
import { User } from '../users/entities/user.entity';
import { ShipmentStatus } from '../common/enums';

function istDayStart(d: string): Date { return new Date(`${d}T00:00:00+05:30`); }
function istDayEnd(d: string): Date { return new Date(`${d}T23:59:59.999+05:30`); }

@Injectable()
export class ShippingService {
  private readonly logger = new Logger(ShippingService.name);
  private readonly adapters: Record<string, ICarrierAdapter>;
  private readonly shipper: {
    name: string; address: string; city: string; state: string; zip: string; country: string; phone: string;
  };

  constructor(
    @InjectRepository(Shipment) private readonly repo: Repository<Shipment>,
    @InjectRepository(BillingOrder) private readonly orderRepo: Repository<BillingOrder>,
    private readonly config: ConfigService,
    private readonly fedex: FedexAdapter,
    private readonly dhl: DhlAdapter,
    private readonly ups: UpsAdapter,
  ) {
    this.adapters = { FEDEX: fedex, DHL: dhl, UPS: ups };
    this.shipper = {
      name: config.get('SHIPPER_NAME', 'The Sangemarmar'),
      address: config.get('SHIPPER_ADDRESS', 'Sangemarmar'),
      city: config.get('SHIPPER_CITY', 'Agra'),
      state: config.get('SHIPPER_STATE', 'UP'),
      zip: config.get('SHIPPER_ZIP', '282001'),
      country: config.get('SHIPPER_COUNTRY', 'IN'),
      phone: config.get('SHIPPER_PHONE', ''),
    };
  }

  private getAdapter(carrier: string): ICarrierAdapter {
    const adapter = this.adapters[carrier.toUpperCase()];
    if (!adapter) throw new BadRequestException(`Unknown carrier: ${carrier}`);
    return adapter;
  }

  async getRates(dto: GetRatesDto): Promise<{ carrier: string; quotes: RateQuote[]; error?: string }[]> {
    let recipient = { name: '', address: '', city: '', state: '', zip: '', country: '', phone: '', email: '' };

    if (dto.billingOrderId) {
      const order = await this.orderRepo.findOne({ where: { id: dto.billingOrderId } });
      if (!order) throw new NotFoundException('Billing order not found');
      recipient = {
        name: order.buyerName,
        address: order.buyerAddress,
        city: order.buyerCity,
        state: order.buyerState,
        zip: order.buyerZip,
        country: order.buyerCountry,
        phone: order.buyerWhatsApp,
        email: order.buyerEmail,
      };
    }

    const req: Omit<ShipmentRequest, 'carrier' | 'serviceCode'> = {
      shipper: this.shipper,
      recipient,
      weightKg: dto.weightKg,
      lengthCm: dto.lengthCm,
      widthCm: dto.widthCm,
      heightCm: dto.heightCm,
      declaredValueUsd: dto.declaredValueUsd,
      contentsDescription: dto.contentsDescription,
      shipDate: dto.shipDate,
    };

    const results = await Promise.allSettled([
      this.fedex.getRates(req).then((q) => ({ carrier: 'FEDEX', quotes: q })),
      this.dhl.getRates(req).then((q) => ({ carrier: 'DHL', quotes: q })),
      this.ups.getRates(req).then((q) => ({ carrier: 'UPS', quotes: q })),
    ]);

    return results.map((r, i) => {
      const label = ['FEDEX', 'DHL', 'UPS'][i];
      if (r.status === 'fulfilled') return r.value;
      const err = r.reason;
      const detail = err?.response?.data
        ? JSON.stringify(err.response.data)
        : err?.message ?? 'Unknown error';
      this.logger.error(`${label} rates failed: ${detail}`);
      return { carrier: label, quotes: [], error: detail };
    });
  }

  async create(dto: CreateShipmentDto, user: User): Promise<Shipment> {
    const adapter = this.getAdapter(dto.carrier);

    const req: ShipmentRequest = {
      carrier: dto.carrier,
      serviceCode: dto.serviceCode,
      shipper: this.shipper,
      recipient: {
        name: dto.recipientName,
        address: dto.recipientAddress,
        city: dto.recipientCity,
        state: dto.recipientState,
        zip: dto.recipientZip,
        country: dto.recipientCountry,
        phone: dto.recipientPhone,
        email: dto.recipientEmail,
      },
      weightKg: dto.weightKg,
      lengthCm: dto.lengthCm,
      widthCm: dto.widthCm,
      heightCm: dto.heightCm,
      declaredValueUsd: dto.declaredValueUsd,
      contentsDescription: dto.contentsDescription,
      shipDate: dto.shipDate,
    };

    const result = await adapter.createShipment(req);

    const shipment = this.repo.create({
      billingOrderId: dto.billingOrderId,
      carrier: dto.carrier as any,
      serviceCode: dto.serviceCode,
      serviceLabel: dto.serviceLabel,
      carrierShipmentId: result.carrierShipmentId,
      trackingNumber: result.trackingNumber,
      labelBase64: result.labelBase64,
      status: ShipmentStatus.LABEL_CREATED,
      estimatedDelivery: result.estimatedDelivery ? new Date(result.estimatedDelivery) : null,
      shipperName: this.shipper.name,
      shipperAddress: this.shipper.address,
      shipperCity: this.shipper.city,
      shipperState: this.shipper.state,
      shipperZip: this.shipper.zip,
      shipperCountry: this.shipper.country,
      shipperPhone: this.shipper.phone,
      recipientName: dto.recipientName,
      recipientAddress: dto.recipientAddress,
      recipientCity: dto.recipientCity,
      recipientState: dto.recipientState,
      recipientZip: dto.recipientZip,
      recipientCountry: dto.recipientCountry,
      recipientPhone: dto.recipientPhone,
      recipientEmail: dto.recipientEmail,
      weightKg: dto.weightKg,
      lengthCm: dto.lengthCm,
      widthCm: dto.widthCm,
      heightCm: dto.heightCm,
      declaredValueUsd: dto.declaredValueUsd,
      contentsDescription: dto.contentsDescription,
      quotedCostUsd: result.costUsd || dto.quotedCostUsd,
      shipDate: new Date(dto.shipDate),
      createdById: user.id,
    });

    return this.repo.save(shipment);
  }

  async findAll(filter: ShipmentFilterDto): Promise<Shipment[]> {
    const where: any = {};
    if (filter.billingOrderId) where.billingOrderId = filter.billingOrderId;
    if (filter.carrier) where.carrier = filter.carrier.toUpperCase();
    if (filter.dateFrom && filter.dateTo) {
      where.shipDate = Between(istDayStart(filter.dateFrom), istDayEnd(filter.dateTo));
    } else if (filter.dateFrom) {
      where.shipDate = MoreThanOrEqual(istDayStart(filter.dateFrom));
    } else if (filter.dateTo) {
      where.shipDate = LessThanOrEqual(istDayEnd(filter.dateTo));
    }
    return this.repo.find({ where, relations: ['billingOrder', 'createdBy'], order: { createdAt: 'DESC' } });
  }

  async findOne(id: string): Promise<Shipment> {
    const s = await this.repo.findOne({ where: { id }, relations: ['billingOrder', 'createdBy'] });
    if (!s) throw new NotFoundException('Shipment not found');
    return s;
  }

  async getLabel(id: string): Promise<Buffer> {
    const s = await this.findOne(id);
    if (!s.labelBase64) throw new NotFoundException('Label not available');
    return Buffer.from(s.labelBase64, 'base64');
  }

  async track(id: string): Promise<any> {
    const s = await this.findOne(id);
    if (!s.trackingNumber) throw new BadRequestException('No tracking number for this shipment');
    const adapter = this.getAdapter(s.carrier);
    const result = await adapter.trackShipment(s.trackingNumber);

    // Update status in DB
    const mappedStatus = result.status as ShipmentStatus;
    if (Object.values(ShipmentStatus).includes(mappedStatus) && s.status !== mappedStatus) {
      await this.repo.update(id, {
        status: mappedStatus,
        ...(result.estimatedDelivery ? { estimatedDelivery: new Date(result.estimatedDelivery) } : {}),
      });
    }

    return result;
  }

  async delete(id: string): Promise<void> {
    await this.findOne(id);
    await this.repo.delete(id);
  }
}

import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { ShipmentCarrier, ShipmentStatus } from '../../common/enums';
import { BillingOrder } from '../../billing/entities/billing-order.entity';
import { User } from '../../users/entities/user.entity';

@Entity('shipments')
export class Shipment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true })
  billingOrderId: string;

  @ManyToOne(() => BillingOrder, { nullable: true, eager: false, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'billingOrderId' })
  billingOrder: BillingOrder;

  @Column({ type: 'varchar', length: 20 })
  carrier: ShipmentCarrier;

  @Column()
  serviceCode: string;

  @Column()
  serviceLabel: string;

  @Column({ nullable: true })
  carrierShipmentId: string;

  @Column({ nullable: true })
  trackingNumber: string;

  @Column({ type: 'text', nullable: true })
  labelBase64: string;

  @Column({ type: 'varchar', length: 20, default: ShipmentStatus.LABEL_CREATED })
  status: ShipmentStatus;

  @Column({ type: 'date', nullable: true })
  estimatedDelivery: Date;

  // Shipper (company — from env)
  @Column() shipperName: string;
  @Column() shipperAddress: string;
  @Column() shipperCity: string;
  @Column() shipperState: string;
  @Column() shipperZip: string;
  @Column() shipperCountry: string;
  @Column() shipperPhone: string;

  // Recipient (from billing order buyer)
  @Column() recipientName: string;
  @Column() recipientAddress: string;
  @Column() recipientCity: string;
  @Column() recipientState: string;
  @Column() recipientZip: string;
  @Column() recipientCountry: string;
  @Column() recipientPhone: string;
  @Column() recipientEmail: string;

  // Package
  @Column({ type: 'decimal', precision: 8, scale: 3 })
  weightKg: number;

  @Column({ type: 'decimal', precision: 8, scale: 1, nullable: true })
  lengthCm: number;

  @Column({ type: 'decimal', precision: 8, scale: 1, nullable: true })
  widthCm: number;

  @Column({ type: 'decimal', precision: 8, scale: 1, nullable: true })
  heightCm: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  declaredValueUsd: number;

  @Column()
  contentsDescription: string;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  quotedCostUsd: number;

  @Column({ type: 'date' })
  shipDate: Date;

  @Column({ nullable: true })
  createdById: string;

  @ManyToOne(() => User, { nullable: true, eager: false })
  @JoinColumn({ name: 'createdById' })
  createdBy: User;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

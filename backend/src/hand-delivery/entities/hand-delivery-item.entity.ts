import {
  Entity, PrimaryGeneratedColumn, Column,
  ManyToOne, JoinColumn,
} from 'typeorm';
import { HandDeliveryOrder } from './hand-delivery-order.entity';

@Entity('hand_delivery_items')
export class HandDeliveryItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  handDeliveryOrderId: string;

  @ManyToOne(() => HandDeliveryOrder, (o) => o.items, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'handDeliveryOrderId' })
  handDeliveryOrder: HandDeliveryOrder;

  @Column()
  particulars: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  hsnCode: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  size: string;

  @Column({ type: 'int' })
  quantity: number;

  // Reverse-calc fields: user enters `amountInr` (line total inclusive of GST);
  // backend derives the rest. `priceInr` is the per-unit taxable price (kept
  // for backward compatibility with older voucher PDF code paths).
  @Column({ type: 'decimal', precision: 12, scale: 2 })
  priceInr: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amountInr: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 5 })
  gstRate: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  taxableValue: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  gstAmount: number;
}

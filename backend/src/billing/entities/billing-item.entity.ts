import {
  Entity, PrimaryGeneratedColumn, Column,
  ManyToOne, JoinColumn,
} from 'typeorm';
import { BillingOrder } from './billing-order.entity';

@Entity('billing_items')
export class BillingItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  billingOrderId: string;

  @ManyToOne(() => BillingOrder, (o) => o.items, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'billingOrderId' })
  billingOrder: BillingOrder;

  @Column()
  particulars: string;

  @Column({ type: 'int' })
  quantity: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  priceUsd: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amountUsd: number;
}

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

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  priceInr: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amountInr: number;
}

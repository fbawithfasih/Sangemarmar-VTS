import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { BillingOrderStatus, InvoiceType } from '../../common/enums';
import { User } from '../../users/entities/user.entity';
import { HandDeliveryItem } from './hand-delivery-item.entity';

@Entity('hand_delivery_orders')
export class HandDeliveryOrder {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  invoiceNumber: string;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  orderDate: Date;

  @Column({ type: 'varchar', length: 20, default: BillingOrderStatus.DRAFT })
  status: BillingOrderStatus;

  // New (post-2026 GST redesign) -----------------------------------------
  @Column({ type: 'varchar', length: 20, default: InvoiceType.INTER_STATE })
  invoiceType: InvoiceType;

  @Column({ nullable: true })
  gstin: string;

  // Combined free-text field: user types either DOB or Passport No.
  @Column({ nullable: true })
  dobPassport: string;

  // Buyer's slimmed-down details
  @Column() buyerName: string;
  @Column({ nullable: true }) buyerState: string;
  @Column({ nullable: true }) buyerCountry: string;
  @Column({ nullable: true }) buyerEmail: string;
  @Column({ nullable: true }) buyerCellAreaCode: string;
  @Column({ nullable: true }) buyerCellNo: string;

  // Legacy columns retained as nullable for historical data; not used by new UI.
  @Column({ nullable: true }) buyerAddress: string;
  @Column({ nullable: true }) buyerCity: string;
  @Column({ nullable: true }) buyerZip: string;
  @Column({ nullable: true }) buyerWhatsApp: string;
  @Column({ nullable: true }) buyerPassportNo: string;
  @Column({ nullable: true, type: 'date' }) buyerDOB: Date;
  @Column({ nullable: true }) buyerNationality: string;
  @Column({ nullable: true }) buyerSeaPort: string;
  @Column({ nullable: true }) notes: string;

  @OneToMany(() => HandDeliveryItem, (item) => item.handDeliveryOrder, { cascade: true })
  items: HandDeliveryItem[];

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

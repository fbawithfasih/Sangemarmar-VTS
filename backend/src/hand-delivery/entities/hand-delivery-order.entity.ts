import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { BillingOrderStatus } from '../../common/enums';
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

  @Column() buyerName: string;
  @Column() buyerAddress: string;
  @Column() buyerCity: string;
  @Column() buyerState: string;
  @Column() buyerZip: string;
  @Column() buyerCountry: string;
  @Column() buyerEmail: string;
  @Column() buyerWhatsApp: string;
  @Column({ nullable: true }) buyerCellAreaCode: string;
  @Column({ nullable: true }) buyerCellNo: string;
  @Column() buyerPassportNo: string;
  @Column({ nullable: true, type: 'date' }) buyerDOB: Date;
  @Column() buyerNationality: string;
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

import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { BillingOrderStatus } from '../../common/enums';
import { VehicleEntry } from '../../vehicles/entities/vehicle-entry.entity';
import { User } from '../../users/entities/user.entity';
import { BillingItem } from './billing-item.entity';

@Entity('billing_orders')
export class BillingOrder {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  invoiceNumber: string;

  @Column({ nullable: true })
  vehicleEntryId: string | null;

  @ManyToOne(() => VehicleEntry, { eager: false, onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'vehicleEntryId' })
  vehicleEntry: VehicleEntry | null;

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
  @Column() buyerSeaPort: string;
  @Column({ nullable: true }) notes: string;

  @OneToMany(() => BillingItem, (item) => item.billingOrder, { cascade: true })
  items: BillingItem[];

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

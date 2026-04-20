import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { OrderType, WorkflowStatus } from '../../common/enums';
import { VehicleEntry } from '../../vehicles/entities/vehicle-entry.entity';
import { User } from '../../users/entities/user.entity';

@Entity('sales')
export class Sale {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  vehicleEntryId: string;

  @ManyToOne(() => VehicleEntry, { eager: false })
  @JoinColumn({ name: 'vehicleEntryId' })
  vehicleEntry: VehicleEntry;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  grossSale: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  netSale: number;

  @Column()
  salesperson: string;

  @Column({ type: 'enum', enum: OrderType })
  orderType: OrderType;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  saleDate: Date;

  @Column({ type: 'enum', enum: WorkflowStatus, default: WorkflowStatus.SALES_COMPLETE })
  status: WorkflowStatus;

  @Column({ nullable: true })
  notes: string;

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

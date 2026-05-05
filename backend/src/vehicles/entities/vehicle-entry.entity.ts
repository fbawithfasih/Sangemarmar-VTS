import {
  Entity, PrimaryGeneratedColumn, Column, Index,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { WorkflowStatus } from '../../common/enums';
import { User } from '../../users/entities/user.entity';

@Entity('vehicle_entries')
export class VehicleEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  vehicleNumber: string;

  @Index()
  @Column()
  driverName: string;

  @Column({ nullable: true })
  driverMobile: string;

  @Index()
  @Column()
  guideName: string;

  @Column({ nullable: true })
  guideMobile: string;

  @Index()
  @Column()
  localAgent: string;

  @Index()
  @Column()
  companyName: string;

  @Index()
  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  entryDate: Date;

  @Index()
  @Column({ type: 'enum', enum: WorkflowStatus, default: WorkflowStatus.ENTERED })
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

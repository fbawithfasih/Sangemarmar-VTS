import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne,
  JoinColumn, OneToMany,
} from 'typeorm';
import { WorkflowStatus } from '../../common/enums';
import { User } from '../../users/entities/user.entity';

@Entity('vehicle_entries')
export class VehicleEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  vehicleNumber: string;

  @Column()
  driverName: string;

  @Column({ nullable: true })
  driverMobile: string;

  @Column()
  guideName: string;

  @Column({ nullable: true })
  guideMobile: string;

  @Column()
  localAgent: string;

  @Column()
  companyName: string;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  entryDate: Date;

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

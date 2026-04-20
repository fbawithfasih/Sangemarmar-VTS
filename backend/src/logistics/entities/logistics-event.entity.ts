import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { WorkflowStatus } from '../../common/enums';
import { VehicleEntry } from '../../vehicles/entities/vehicle-entry.entity';
import { User } from '../../users/entities/user.entity';

@Entity('logistics_events')
export class LogisticsEvent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  vehicleEntryId: string;

  @ManyToOne(() => VehicleEntry, { eager: false })
  @JoinColumn({ name: 'vehicleEntryId' })
  vehicleEntry: VehicleEntry;

  @Column({ type: 'enum', enum: WorkflowStatus })
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
}

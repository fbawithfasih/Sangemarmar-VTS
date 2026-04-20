import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum NotificationType {
  VEHICLE_ENTRY = 'VEHICLE_ENTRY',
  SALE = 'SALE',
  PAYMENT = 'PAYMENT',
  COMMISSION = 'COMMISSION',
}

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column()
  message: string;

  @Column({ nullable: true })
  entityId: string;

  @Column({ nullable: true })
  actorName: string;

  @Column({ default: false })
  isRead: boolean;

  @Column({ nullable: true })
  actorId: string;

  @ManyToOne(() => User, { nullable: true, eager: false })
  @JoinColumn({ name: 'actorId' })
  actor: User;

  @CreateDateColumn()
  createdAt: Date;
}

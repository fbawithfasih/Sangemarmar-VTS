import {
  Entity, PrimaryGeneratedColumn, Column,
  UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { CommissionRecipientType } from '../../common/enums';
import { User } from '../../users/entities/user.entity';

@Entity('commission_configs')
export class CommissionConfig {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: CommissionRecipientType, unique: true })
  recipientType: CommissionRecipientType;

  @Column({ type: 'decimal', precision: 5, scale: 2 })
  rate: number;

  @Column({ nullable: true })
  updatedById: string;

  @ManyToOne(() => User, { nullable: true, eager: false })
  @JoinColumn({ name: 'updatedById' })
  updatedBy: User;

  @UpdateDateColumn()
  updatedAt: Date;
}

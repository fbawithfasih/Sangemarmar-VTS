import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { CommissionRecipientType } from '../../common/enums';
import { Sale } from '../../sales/entities/sale.entity';
import { User } from '../../users/entities/user.entity';

@Entity('commissions')
export class Commission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  saleId: string;

  @ManyToOne(() => Sale, { eager: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'saleId' })
  sale: Sale;

  @Column({ type: 'enum', enum: CommissionRecipientType })
  recipientType: CommissionRecipientType;

  @Column()
  recipientName: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  rate: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  calculatedAmount: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  finalAmount: number;

  @Column({ default: false })
  isOverridden: boolean;

  @Column({ nullable: true })
  overrideReason: string;

  @Column({ nullable: true })
  overriddenById: string;

  @ManyToOne(() => User, { nullable: true, eager: false })
  @JoinColumn({ name: 'overriddenById' })
  overriddenBy: User;

  @Column({ nullable: true })
  overriddenAt: Date;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  paidAmount: number;

  @Column({ type: 'date', nullable: true })
  paidAt: Date;

  @Column({ type: 'text', nullable: true })
  paidNote: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

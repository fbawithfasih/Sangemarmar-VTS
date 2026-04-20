import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { PaymentMode } from '../../common/enums';
import { Sale } from '../../sales/entities/sale.entity';
import { User } from '../../users/entities/user.entity';

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  saleId: string;

  @ManyToOne(() => Sale, { eager: false })
  @JoinColumn({ name: 'saleId' })
  sale: Sale;

  @Column({ type: 'enum', enum: PaymentMode })
  mode: PaymentMode;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  paymentDate: Date;

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

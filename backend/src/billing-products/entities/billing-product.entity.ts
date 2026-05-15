import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index,
} from 'typeorm';

// Reusable product catalog for hand-delivery / billing line items.
// Provides description -> HSN auto-pick and a stored GST rate per product.
// GST rate is metadata for now (current pricing uses a fixed 5%), kept so
// rate-per-product can be flipped on later without a migration.
@Entity('billing_products')
export class BillingProduct {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column()
  description: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  hsnCode: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 5 })
  gstRate: number;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

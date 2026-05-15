import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BillingProduct } from './entities/billing-product.entity';
import { CreateBillingProductDto, UpdateBillingProductDto } from './dto/billing-product.dto';

@Injectable()
export class BillingProductsService {
  constructor(
    @InjectRepository(BillingProduct) private readonly repo: Repository<BillingProduct>,
  ) {}

  async findAll(includeInactive = false): Promise<BillingProduct[]> {
    const where = includeInactive ? {} : { isActive: true };
    return this.repo.find({ where, order: { description: 'ASC' } });
  }

  async findOne(id: string): Promise<BillingProduct> {
    const p = await this.repo.findOne({ where: { id } });
    if (!p) throw new NotFoundException('Product not found');
    return p;
  }

  async create(dto: CreateBillingProductDto): Promise<BillingProduct> {
    const description = dto.description.trim();
    if (!description) throw new BadRequestException('Description is required');
    const existing = await this.repo.findOne({ where: { description } });
    if (existing) {
      // Reactivate-on-conflict: makes the "Add a product" flow idempotent for
      // users who re-add the same description after deactivating it.
      existing.hsnCode = dto.hsnCode ?? existing.hsnCode;
      existing.gstRate = dto.gstRate ?? existing.gstRate;
      existing.isActive = true;
      return this.repo.save(existing);
    }
    const p = this.repo.create({
      description,
      hsnCode: dto.hsnCode,
      gstRate: dto.gstRate ?? 5,
    });
    return this.repo.save(p);
  }

  async update(id: string, dto: UpdateBillingProductDto): Promise<BillingProduct> {
    const p = await this.findOne(id);
    Object.assign(p, dto);
    return this.repo.save(p);
  }

  async delete(id: string): Promise<void> {
    // Soft delete to preserve historical references on hand-delivery items.
    const p = await this.findOne(id);
    p.isActive = false;
    await this.repo.save(p);
  }
}

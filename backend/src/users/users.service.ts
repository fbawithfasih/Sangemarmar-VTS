import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UserRole } from '../common/enums';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findOne({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Email already in use');

    const hashed = await bcrypt.hash(dto.password, 10);
    const user = this.repo.create({ ...dto, password: hashed });
    return this.repo.save(user);
  }

  async findAll(): Promise<User[]> {
    return this.repo.find({ select: ['id', 'name', 'email', 'role', 'isActive', 'createdAt'] });
  }

  async findSalesmen(): Promise<Pick<User, 'id' | 'name'>[]> {
    return this.repo.find({
      where: { role: UserRole.SALES_STAFF, isActive: true },
      select: ['id', 'name'],
      order: { name: 'ASC' },
    });
  }

  async findById(id: string): Promise<User> {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async findByIdLean(id: string): Promise<User | null> {
    return this.repo.findOne({
      where: { id },
      select: ['id', 'name', 'email', 'role', 'isActive', 'createdAt', 'updatedAt'],
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.repo
      .createQueryBuilder('u')
      .addSelect('u.password')
      .where('u.email = :email', { email })
      .getOne();
  }

  async deactivate(id: string): Promise<void> {
    await this.repo.update(id, { isActive: false });
  }

  async toggleActive(id: string): Promise<User> {
    const user = await this.findById(id);
    await this.repo.update(id, { isActive: !user.isActive });
    return this.findById(id);
  }
}

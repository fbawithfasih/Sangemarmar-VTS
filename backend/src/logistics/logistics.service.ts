import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LogisticsEvent } from './entities/logistics-event.entity';
import { CreateLogisticsEventDto } from './dto/create-logistics-event.dto';

@Injectable()
export class LogisticsService {
  constructor(
    @InjectRepository(LogisticsEvent)
    private readonly repo: Repository<LogisticsEvent>,
  ) {}

  async addEvent(dto: CreateLogisticsEventDto, userId?: string): Promise<LogisticsEvent> {
    const event = this.repo.create({ ...dto, createdById: userId });
    return this.repo.save(event);
  }

  async getTimeline(vehicleEntryId: string): Promise<LogisticsEvent[]> {
    return this.repo.find({
      where: { vehicleEntryId },
      order: { createdAt: 'ASC' },
      relations: ['createdBy'],
    });
  }
}

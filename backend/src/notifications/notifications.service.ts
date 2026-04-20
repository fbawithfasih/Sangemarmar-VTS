import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { Notification, NotificationType } from './entities/notification.entity';

export interface CreateNotificationDto {
  type: NotificationType;
  message: string;
  entityId?: string;
  actorId?: string;
  actorName?: string;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly repo: Repository<Notification>,
    private readonly httpService: HttpService,
    private readonly config: ConfigService,
  ) {}

  async create(dto: CreateNotificationDto): Promise<Notification> {
    const notification = this.repo.create(dto);
    const saved = await this.repo.save(notification);

    // Fire & forget external notifications
    this.sendTelegram(dto.message).catch(() => {});
    this.sendWhatsApp(dto.message).catch(() => {});

    return saved;
  }

  async findAll(): Promise<Notification[]> {
    return this.repo.find({ order: { createdAt: 'DESC' }, take: 100 });
  }

  async unreadCount(): Promise<number> {
    return this.repo.count({ where: { isRead: false } });
  }

  async markRead(id: string): Promise<void> {
    await this.repo.update(id, { isRead: true });
  }

  async markAllRead(): Promise<void> {
    await this.repo.update({ isRead: false }, { isRead: true });
  }

  private async sendTelegram(message: string): Promise<void> {
    const token = this.config.get<string>('TELEGRAM_BOT_TOKEN');
    const chatId = this.config.get<string>('TELEGRAM_CHAT_ID');
    if (!token || !chatId) return;

    try {
      await firstValueFrom(
        this.httpService.post(`https://api.telegram.org/bot${token}/sendMessage`, {
          chat_id: chatId,
          text: `🏢 *Sangemarmar VTS*\n\n${message}`,
          parse_mode: 'Markdown',
        }),
      );
    } catch (e) {
      this.logger.warn(`Telegram send failed: ${e.message}`);
    }
  }

  private async sendWhatsApp(message: string): Promise<void> {
    const accountSid = this.config.get<string>('TWILIO_ACCOUNT_SID');
    const authToken = this.config.get<string>('TWILIO_AUTH_TOKEN');
    const from = this.config.get<string>('TWILIO_WHATSAPP_FROM');
    const to = this.config.get<string>('TWILIO_WHATSAPP_TO');
    if (!accountSid || !authToken || !from || !to) return;

    try {
      const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
      const body = new URLSearchParams({
        From: `whatsapp:${from}`,
        To: `whatsapp:${to}`,
        Body: `🏢 Sangemarmar VTS\n\n${message}`,
      });
      await firstValueFrom(
        this.httpService.post(url, body.toString(), {
          auth: { username: accountSid, password: authToken },
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        }),
      );
    } catch (e) {
      this.logger.warn(`WhatsApp send failed: ${e.message}`);
    }
  }
}

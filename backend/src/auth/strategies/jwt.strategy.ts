import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { User } from '../../users/entities/user.entity';

const USER_CACHE_TTL_MS = 60 * 1000;

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  private readonly userCache = new Map<string, { expiresAt: number; user: User }>();

  constructor(
    private readonly config: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string; role: string }) {
    const cached = this.userCache.get(payload.sub);
    if (cached && cached.expiresAt > Date.now()) {
      if (!cached.user.isActive) throw new UnauthorizedException();
      return cached.user;
    }

    const user = await this.usersService.findByIdLean(payload.sub);
    if (!user || !user.isActive) {
      this.userCache.delete(payload.sub);
      throw new UnauthorizedException();
    }
    this.userCache.set(payload.sub, { expiresAt: Date.now() + USER_CACHE_TTL_MS, user });
    return user;
  }
}

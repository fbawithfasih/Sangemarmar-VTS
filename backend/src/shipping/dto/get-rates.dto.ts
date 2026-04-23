import { IsDateString, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class GetRatesDto {
  @IsOptional()
  @IsUUID()
  billingOrderId?: string;

  @IsNumber()
  @Min(0.01)
  @Type(() => Number)
  weightKg: number;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  lengthCm?: number;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  widthCm?: number;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  heightCm?: number;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  declaredValueUsd: number;

  @IsString()
  contentsDescription: string;

  @IsDateString()
  shipDate: string;
}

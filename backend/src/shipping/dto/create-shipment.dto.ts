import { IsDateString, IsIn, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateShipmentDto {
  @IsOptional()
  @IsUUID()
  billingOrderId?: string;

  @IsIn(['FEDEX', 'DHL', 'UPS'])
  carrier: string;

  @IsString()
  serviceCode: string;

  @IsString()
  serviceLabel: string;

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

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  quotedCostUsd: number;

  @IsDateString()
  shipDate: string;

  // Recipient (provided by client — pre-filled from billing order)
  @IsString() recipientName: string;
  @IsString() recipientAddress: string;
  @IsString() recipientCity: string;
  @IsString() recipientState: string;
  @IsString() recipientZip: string;
  @IsString() recipientCountry: string;
  @IsString() recipientPhone: string;
  @IsString() recipientEmail: string;
}

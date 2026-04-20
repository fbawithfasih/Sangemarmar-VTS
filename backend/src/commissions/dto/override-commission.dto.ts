import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class OverrideCommissionDto {
  @IsNumber()
  @Min(0)
  finalAmount: number;

  @IsOptional()
  @IsString()
  overrideReason?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  rate?: number;
}

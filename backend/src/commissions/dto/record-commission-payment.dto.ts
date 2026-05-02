import { IsDateString, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class RecordCommissionPaymentDto {
  @IsNumber()
  @Min(0.01)
  paidAmount: number;

  @IsDateString()
  paidAt: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  paidNote?: string;
}

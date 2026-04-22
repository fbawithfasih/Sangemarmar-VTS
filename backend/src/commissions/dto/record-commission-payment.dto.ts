import { IsDateString, IsNumber, Min } from 'class-validator';

export class RecordCommissionPaymentDto {
  @IsNumber()
  @Min(0.01)
  paidAmount: number;

  @IsDateString()
  paidAt: string;
}

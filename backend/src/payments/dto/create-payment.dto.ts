import {
  IsDateString, IsEnum, IsNumber, IsOptional,
  IsPositive, IsString, IsUUID,
} from 'class-validator';
import { PaymentMode } from '../../common/enums';

export class CreatePaymentDto {
  @IsUUID()
  saleId: string;

  @IsEnum(PaymentMode)
  mode: PaymentMode;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsDateString()
  paymentDate?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

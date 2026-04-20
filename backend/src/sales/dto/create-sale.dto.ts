import {
  IsDateString, IsEnum, IsNotEmpty, IsNumber,
  IsOptional, IsPositive, IsString, IsUUID,
} from 'class-validator';
import { OrderType } from '../../common/enums';

export class CreateSaleDto {
  @IsUUID()
  vehicleEntryId: string;

  @IsNumber()
  @IsPositive()
  grossSale: number;

  @IsNumber()
  @IsPositive()
  netSale: number;

  @IsNotEmpty()
  @IsString()
  salesperson: string;

  @IsEnum(OrderType)
  orderType: OrderType;

  @IsOptional()
  @IsDateString()
  saleDate?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

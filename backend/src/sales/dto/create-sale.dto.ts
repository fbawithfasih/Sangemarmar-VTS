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

// vehicleEntryId is intentionally not editable: a sale's commissions and the
// vehicle's workflow status are tied to the entry it was created against.
export class UpdateSaleDto {
  @IsOptional() @IsNumber() @IsPositive() grossSale?: number;
  @IsOptional() @IsNumber() @IsPositive() netSale?: number;
  @IsOptional() @IsNotEmpty() @IsString() salesperson?: string;
  @IsOptional() @IsEnum(OrderType) orderType?: OrderType;
  @IsOptional() @IsDateString() saleDate?: string;
  @IsOptional() @IsString() notes?: string;
}

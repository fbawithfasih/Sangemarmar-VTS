import {
  IsString, IsEmail, IsOptional, IsDateString,
  IsArray, ValidateNested, ArrayMinSize, IsInt, IsNumber, Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateHandDeliveryItemDto {
  @IsString() particulars: string;
  @IsOptional() @IsString() hsnCode?: string;
  @IsOptional() @IsString() size?: string;
  @IsInt() @Min(1) quantity: number;
  @IsNumber() @Min(0) priceInr: number;
}

export class CreateHandDeliveryDto {
  @IsDateString() orderDate: string;

  @IsString() buyerName: string;
  @IsString() buyerAddress: string;
  @IsString() buyerCity: string;
  @IsString() buyerState: string;
  @IsString() buyerZip: string;
  @IsString() buyerCountry: string;
  @IsEmail() buyerEmail: string;
  @IsString() buyerWhatsApp: string;
  @IsOptional() @IsString() buyerCellAreaCode?: string;
  @IsOptional() @IsString() buyerCellNo?: string;
  @IsString() buyerPassportNo: string;
  @IsOptional() @IsDateString() buyerDOB?: string;
  @IsString() buyerNationality: string;
  @IsOptional() @IsString() buyerSeaPort?: string;
  @IsOptional() @IsString() notes?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateHandDeliveryItemDto)
  items: CreateHandDeliveryItemDto[];
}

export class UpdateHandDeliveryDto {
  @IsOptional() @IsDateString() orderDate?: string;
  @IsOptional() @IsString() buyerName?: string;
  @IsOptional() @IsString() buyerAddress?: string;
  @IsOptional() @IsString() buyerCity?: string;
  @IsOptional() @IsString() buyerState?: string;
  @IsOptional() @IsString() buyerZip?: string;
  @IsOptional() @IsString() buyerCountry?: string;
  @IsOptional() @IsEmail() buyerEmail?: string;
  @IsOptional() @IsString() buyerWhatsApp?: string;
  @IsOptional() @IsString() buyerCellAreaCode?: string;
  @IsOptional() @IsString() buyerCellNo?: string;
  @IsOptional() @IsString() buyerPassportNo?: string;
  @IsOptional() @IsDateString() buyerDOB?: string;
  @IsOptional() @IsString() buyerNationality?: string;
  @IsOptional() @IsString() buyerSeaPort?: string;
  @IsOptional() @IsString() notes?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateHandDeliveryItemDto)
  items?: CreateHandDeliveryItemDto[];
}

export class HandDeliveryFilterDto {
  @IsOptional() @IsString() dateFrom?: string;
  @IsOptional() @IsString() dateTo?: string;
  @IsOptional() @IsString() format?: string;
}

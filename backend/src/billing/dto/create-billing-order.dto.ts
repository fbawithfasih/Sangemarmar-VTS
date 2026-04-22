import {
  IsUUID, IsString, IsEmail, IsOptional, IsDateString,
  IsArray, ValidateNested, ArrayMinSize, IsInt, IsNumber, Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateBillingItemDto {
  @IsString() particulars: string;
  @IsInt() @Min(1) quantity: number;
  @IsNumber() @Min(0) priceUsd: number;
}

export class CreateBillingOrderDto {
  @IsUUID() vehicleEntryId: string;
  @IsDateString() orderDate: string;

  @IsString() buyerName: string;
  @IsString() buyerAddress: string;
  @IsString() buyerCity: string;
  @IsString() buyerState: string;
  @IsString() buyerZip: string;
  @IsString() buyerCountry: string;
  @IsEmail() buyerEmail: string;
  @IsString() buyerWhatsApp: string;
  @IsString() buyerPassportNo: string;
  @IsOptional() @IsDateString() buyerDOB?: string;
  @IsString() buyerNationality: string;
  @IsString() buyerSeaPort: string;
  @IsOptional() @IsString() notes?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateBillingItemDto)
  items: CreateBillingItemDto[];
}

export class UpdateBillingOrderDto {
  @IsOptional() @IsDateString() orderDate?: string;
  @IsOptional() @IsString() buyerName?: string;
  @IsOptional() @IsString() buyerAddress?: string;
  @IsOptional() @IsString() buyerCity?: string;
  @IsOptional() @IsString() buyerState?: string;
  @IsOptional() @IsString() buyerZip?: string;
  @IsOptional() @IsString() buyerCountry?: string;
  @IsOptional() @IsEmail() buyerEmail?: string;
  @IsOptional() @IsString() buyerWhatsApp?: string;
  @IsOptional() @IsString() buyerPassportNo?: string;
  @IsOptional() @IsDateString() buyerDOB?: string;
  @IsOptional() @IsString() buyerNationality?: string;
  @IsOptional() @IsString() buyerSeaPort?: string;
  @IsOptional() @IsString() notes?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateBillingItemDto)
  items?: CreateBillingItemDto[];
}

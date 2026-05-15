import {
  IsString, IsEmail, IsOptional, IsDateString, IsEnum,
  IsArray, ValidateNested, ArrayMinSize, IsInt, IsNumber, Min, Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { InvoiceType } from '../../common/enums';

export class CreateHandDeliveryItemDto {
  @IsString() particulars: string;
  @IsOptional() @IsString() hsnCode?: string;
  @IsOptional() @IsString() size?: string;
  @IsInt() @Min(1) quantity: number;

  // Inclusive line total typed by the user. Backend reverse-calculates
  // taxable value and GST amount from this + gstRate.
  @IsNumber() @Min(0) amountInr: number;

  @IsOptional() @IsNumber() @Min(0) @Max(100) gstRate?: number;
}

export class CreateHandDeliveryDto {
  @IsDateString() orderDate: string;

  @IsOptional() @IsEnum(InvoiceType) invoiceType?: InvoiceType;

  // ── Buyer's details (new slim set) ─────────────────────────────────
  @IsString() buyerName: string;
  @IsOptional() @IsString() dobPassport?: string;
  @IsOptional() @IsString() buyerState?: string;
  @IsOptional() @IsString() buyerCountry?: string;
  @IsOptional() @IsString() gstin?: string;
  @IsOptional() @IsEmail() buyerEmail?: string;
  @IsOptional() @IsString() buyerCellAreaCode?: string;
  @IsOptional() @IsString() buyerCellNo?: string;

  // ── Legacy fields (accepted but optional; retained for compatibility) ──
  @IsOptional() @IsString() buyerAddress?: string;
  @IsOptional() @IsString() buyerCity?: string;
  @IsOptional() @IsString() buyerZip?: string;
  @IsOptional() @IsString() buyerWhatsApp?: string;
  @IsOptional() @IsString() buyerPassportNo?: string;
  @IsOptional() @IsDateString() buyerDOB?: string;
  @IsOptional() @IsString() buyerNationality?: string;
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
  @IsOptional() @IsEnum(InvoiceType) invoiceType?: InvoiceType;

  @IsOptional() @IsString() buyerName?: string;
  @IsOptional() @IsString() dobPassport?: string;
  @IsOptional() @IsString() buyerState?: string;
  @IsOptional() @IsString() buyerCountry?: string;
  @IsOptional() @IsString() gstin?: string;
  @IsOptional() @IsEmail() buyerEmail?: string;
  @IsOptional() @IsString() buyerCellAreaCode?: string;
  @IsOptional() @IsString() buyerCellNo?: string;

  @IsOptional() @IsString() buyerAddress?: string;
  @IsOptional() @IsString() buyerCity?: string;
  @IsOptional() @IsString() buyerZip?: string;
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
  @Type(() => CreateHandDeliveryItemDto)
  items?: CreateHandDeliveryItemDto[];
}

export class HandDeliveryFilterDto {
  @IsOptional() @IsString() dateFrom?: string;
  @IsOptional() @IsString() dateTo?: string;
  @IsOptional() @IsString() format?: string;
}

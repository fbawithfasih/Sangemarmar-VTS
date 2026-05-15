import { IsBoolean, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateBillingProductDto {
  @IsString() description: string;
  @IsOptional() @IsString() hsnCode?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100) gstRate?: number;
}

export class UpdateBillingProductDto {
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() hsnCode?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100) gstRate?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

import { IsDateString, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateVehicleEntryDto {
  @IsNotEmpty()
  @IsString()
  vehicleNumber: string;

  @IsNotEmpty()
  @IsString()
  driverName: string;

  @IsNotEmpty()
  @IsString()
  guideName: string;

  @IsNotEmpty()
  @IsString()
  localAgent: string;

  @IsNotEmpty()
  @IsString()
  companyName: string;

  @IsOptional()
  @IsDateString()
  entryDate?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

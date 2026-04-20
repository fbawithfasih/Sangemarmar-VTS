import { IsDateString, IsEnum, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export enum StatementType {
  DRIVER = 'DRIVER',
  GUIDE = 'GUIDE',
  LOCAL_AGENT = 'LOCAL_AGENT',
  COMPANY = 'COMPANY',
}

export class StatementFilterDto {
  @IsEnum(StatementType)
  type: StatementType;

  @IsNotEmpty()
  @IsString()
  name: string;

  @IsOptional()
  @IsDateString()
  dateFrom?: string;

  @IsOptional()
  @IsDateString()
  dateTo?: string;
}

export class ExportStatementDto extends StatementFilterDto {
  @IsIn(['xlsx', 'pdf'])
  format: 'xlsx' | 'pdf';
}

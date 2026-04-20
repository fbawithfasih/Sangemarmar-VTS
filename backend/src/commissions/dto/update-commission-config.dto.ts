import { Type } from 'class-transformer';
import { IsArray, IsEnum, IsNumber, IsPositive, Max, ValidateNested } from 'class-validator';
import { CommissionRecipientType } from '../../common/enums';

export class CommissionRateItemDto {
  @IsEnum(CommissionRecipientType)
  recipientType: CommissionRecipientType;

  @IsNumber()
  @IsPositive()
  @Max(100)
  rate: number;
}

export class UpdateCommissionConfigDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CommissionRateItemDto)
  rates: CommissionRateItemDto[];
}

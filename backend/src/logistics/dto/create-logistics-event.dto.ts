import { IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { WorkflowStatus } from '../../common/enums';

export class CreateLogisticsEventDto {
  @IsUUID()
  vehicleEntryId: string;

  @IsEnum(WorkflowStatus)
  status: WorkflowStatus;

  @IsOptional()
  @IsString()
  notes?: string;
}

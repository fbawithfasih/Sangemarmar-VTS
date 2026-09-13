import { IsEnum } from 'class-validator';
import { WorkflowStatus } from '../../common/enums';

export class UpdateVehicleStatusDto {
  @IsEnum(WorkflowStatus)
  status: WorkflowStatus;
}

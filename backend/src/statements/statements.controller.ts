import { Controller, Get, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { StatementsService } from './statements.service';
import { ExportStatementDto, StatementFilterDto, StatementType } from './dto/statement-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('statements')
@UseGuards(JwtAuthGuard)
export class StatementsController {
  constructor(private readonly statementsService: StatementsService) {}

  @Get('names')
  getUniqueNames(@Query('type') type: StatementType) {
    return this.statementsService.getUniqueNames(type);
  }

  @Get()
  getStatement(@Query() filter: StatementFilterDto) {
    return this.statementsService.getStatement(filter);
  }

  @Get('export')
  async export(@Query() filter: ExportStatementDto, @Res() res: Response) {
    const safeName = filter.name.replace(/[^a-zA-Z0-9_-]/g, '_');
    const filename = `${filter.type}_${safeName}_statement.${filter.format}`;

    if (filter.format === 'xlsx') {
      const buffer = await this.statementsService.exportExcel(filter);
      res.set({
        'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
      res.end(buffer);
    } else {
      const buffer = await this.statementsService.exportPdf(filter);
      res.set({
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
      res.end(buffer);
    }
  }
}

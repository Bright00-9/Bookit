import { Controller, Get, Param, Patch, Delete, Query, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { JobsService } from './jobs.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Jobs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('admin/jobs')
export class JobsController {
  constructor(private jobs: JobsService) {}

  @Get()
  @ApiOperation({ summary: 'Get all jobs with filters' })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'skill', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  findAll(
    @Query('status') status?: string,
    @Query('skill') skill?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.jobs.findAll(status, skill, +page, +limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get job details with applicants' })
  findOne(@Param('id') id: string) {
    return this.jobs.findOne(id);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update job status' })
  updateStatus(
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    return this.jobs.updateStatus(id, status);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a job' })
  delete(@Param('id') id: string) {
    return this.jobs.delete(id);
  }
}

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Analytics')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('admin/analytics')
export class AnalyticsController {
  constructor(private analytics: AnalyticsService) {}

  @Get('overview')
  @ApiOperation({ summary: 'Get platform overview stats' })
  getOverview() {
    return this.analytics.getOverview();
  }

  @Get('jobs-by-skill')
  @ApiOperation({ summary: 'Get job counts grouped by skill' })
  getJobsBySkill() {
    return this.analytics.getJobsBySkill();
  }

  @Get('jobs-over-time')
  @ApiOperation({ summary: 'Get jobs posted per day' })
  @ApiQuery({ name: 'days', required: false })
  getJobsOverTime(@Query('days') days = 30) {
    return this.analytics.getJobsOverTime(+days);
  }

  @Get('users-over-time')
  @ApiOperation({ summary: 'Get user signups per day' })
  @ApiQuery({ name: 'days', required: false })
  getUsersOverTime(@Query('days') days = 30) {
    return this.analytics.getUsersOverTime(+days);
  }

  @Get('top-workers')
  @ApiOperation({ summary: 'Get top rated workers' })
  getTopWorkers() {
    return this.analytics.getTopWorkers();
  }
}

import { Controller, Get, Param, Patch, Delete, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('admin/users')
export class UsersController {
  constructor(private users: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'Get all users with pagination' })
  @ApiQuery({ name: 'role', required: false, enum: ['customer', 'worker'] })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  findAll(
    @Query('role') role?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.users.findAll(role, +page, +limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  findOne(@Param('id') id: string) {
    return this.users.findOne(id);
  }

  @Patch(':id/suspend')
  @ApiOperation({ summary: 'Suspend a user' })
  suspend(@Param('id') id: string) {
    return this.users.suspend(id);
  }

  @Patch(':id/unsuspend')
  @ApiOperation({ summary: 'Unsuspend a user' })
  unsuspend(@Param('id') id: string) {
    return this.users.unsuspend(id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a user' })
  delete(@Param('id') id: string) {
    return this.users.delete(id);
  }
}

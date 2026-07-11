import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
} from '@nestjs/swagger';
import { IsEmail, IsNumber, IsString, IsUUID, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

export class InitializePaymentDto {
  @ApiProperty() @IsUUID() jobId: string;
  @ApiProperty() @IsUUID() workerId: string;
  @ApiProperty() @IsNumber() @Min(1) amount: number;
  @ApiProperty() @IsEmail() customerEmail: string;
}

export class VerifyPaymentDto {
  @ApiProperty() @IsString() reference: string;
}

@ApiTags('Payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private payments: PaymentsService) {}

  @Post('initialize')
  @ApiOperation({ summary: 'Initialize a Paystack payment' })
  initialize(@Body() dto: InitializePaymentDto, @Request() req) {
    return this.payments.initializePayment({
      ...dto,
      customerId: req.user.id,
    });
  }

  @Post('verify')
  @ApiOperation({ summary: 'Verify a Paystack payment' })
  verify(@Body() dto: VerifyPaymentDto) {
    return this.payments.verifyPayment(dto.reference);
  }

  @Get('job/:jobId')
  @ApiOperation({ summary: 'Get payment for a specific job' })
  getJobPayment(@Param('jobId') jobId: string) {
    return this.payments.getJobPayment(jobId);
  }

  @Get()
  @ApiOperation({ summary: 'Get all payments (admin)' })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  getAll(@Query('page') page = 1, @Query('limit') limit = 20) {
    return this.payments.getAllPayments(+page, +limit);
  }
}

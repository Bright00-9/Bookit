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
import { SupabaseAuthGuard } from '../auth/supabase-auth.guard';

export class InitializePaymentDto {
  @ApiProperty() @IsUUID() jobId: string;
  @ApiProperty() @IsUUID() workerId: string;
  @ApiProperty() @IsNumber() @Min(1) amount: number;
  @ApiProperty() @IsEmail() customerEmail: string;
}

export class VerifyPaymentDto {
  @ApiProperty() @IsString() reference: string;
}

export class InitializeAcceptanceDto {
  @ApiProperty() @IsUUID() applicationId: string;
  @ApiProperty() @IsUUID() jobId: string;
  @ApiProperty() @IsUUID() workerId: string;
  @ApiProperty() @IsString() workerMedal: string;
}

export class VerifyReferenceDto {
  @ApiProperty() @IsString() reference: string;
}

export class InitializeApplicationDto {
  @ApiProperty() @IsUUID() jobId: string;
}

@ApiTags('Payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private payments: PaymentsService) {}

  @UseGuards(SupabaseAuthGuard)
  @Post('initialize')
  @ApiOperation({ summary: 'Initialize a Paystack payment' })
  initialize(@Body() dto: InitializePaymentDto, @Request() req) {
    return this.payments.initializePayment({
      ...dto,
      customerId: req.user.id,
      customerEmail: req.user.email ?? '',
    });
  }

  @UseGuards(SupabaseAuthGuard)
  @Post('verify')
  @ApiOperation({ summary: 'Verify a Paystack payment' })
  verify(@Body() dto: VerifyPaymentDto) {
    return this.payments.verifyPayment(dto.reference);
  }

  @UseGuards(SupabaseAuthGuard)
  @Post('acceptance/initialize')
  @ApiOperation({ summary: 'Initialize an acceptance fee payment' })
  initializeAcceptance(@Body() dto: InitializeAcceptanceDto, @Request() req) {
    return this.payments.initializeAcceptanceFee({
      ...dto,
      customerId: req.user.id,
      customerEmail: req.user.email ?? '',
    });
  }

  @UseGuards(SupabaseAuthGuard)
  @Post('acceptance/verify')
  @ApiOperation({ summary: 'Verify an acceptance fee payment' })
  verifyAcceptance(@Body() dto: VerifyReferenceDto) {
    return this.payments.verifyAcceptanceFee(dto.reference);
  }

  @UseGuards(SupabaseAuthGuard)
  @Post('application/initialize')
  @ApiOperation({ summary: 'Initialize an application fee payment' })
  initializeApplication(@Body() dto: InitializeApplicationDto, @Request() req) {
    return this.payments.initializeApplicationFee({
      ...dto,
      workerId: req.user.id,
      workerEmail: req.user.email ?? '',
    });
  }

  @UseGuards(SupabaseAuthGuard)
  @Post('application/verify')
  @ApiOperation({ summary: 'Verify an application fee payment' })
  verifyApplication(@Body() dto: VerifyReferenceDto) {
    return this.payments.verifyApplicationFee(dto.reference);
  }

  @UseGuards(SupabaseAuthGuard)
  @Get('job/:jobId')
  @ApiOperation({ summary: 'Get payment for a specific job' })
  getJobPayment(@Param('jobId') jobId: string) {
    return this.payments.getJobPayment(jobId);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  @ApiOperation({ summary: 'Get all payments (admin)' })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  getAll(@Query('page') page = 1, @Query('limit') limit = 20) {
    return this.payments.getAllPayments(+page, +limit);
  }

}

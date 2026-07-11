import { Injectable, Inject, BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_CLIENT } from '../common/supabase.module';

@Injectable()
export class PaymentsService {
  private readonly paystackSecretKey: string;
  private readonly paystackBaseUrl = 'https://api.paystack.co';

  constructor(
    private config: ConfigService,
    @Inject(SUPABASE_CLIENT) private supabase: SupabaseClient,
  ) {
    this.paystackSecretKey = this.config.get<string>('PAYSTACK_SECRET_KEY');
    if (!this.paystackSecretKey) {
      throw new Error('PAYSTACK_SECRET_KEY must be defined');
    }
  }

  private get headers() {
    return {
      Authorization: 'Bearer ' + this.paystackSecretKey,
      'Content-Type': 'application/json',
    };
  }

  async initializePayment(dto: {
    jobId: string;
    workerId: string;
    customerId: string;
    amount: number;
    customerEmail: string;
  }) {
    const { jobId, workerId, customerId, amount, customerEmail } = dto;

    const { data: existing, error: existingError } = await this.supabase
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .eq('status', 'success')
      .maybeSingle();

    if (existingError) throw new BadRequestException(existingError.message);
    if (existing) {
      throw new BadRequestException('This job has already been paid for');
    }

    const reference = `moka_${jobId.replace(/-/g, '').substring(0, 8)}_${Date.now()}`;

    const { error: insertError } = await this.supabase
      .from('payments')
      .upsert(
        {
          job_id: jobId,
          customer_id: customerId,
          worker_id: workerId,
          amount,
          status: 'pending',
          paystack_reference: reference,
        },
        { onConflict: 'job_id' },
      );

    if (insertError) throw new BadRequestException(insertError.message);

    const response = await fetch(`${this.paystackBaseUrl}/transaction/initialize`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({
        email: customerEmail,
        amount: Math.round(amount * 100),
        currency: 'GHS',
        reference,
        channels: ['card', 'mobile_money'],
        metadata: {
          job_id: jobId,
          worker_id: workerId,
          customer_id: customerId,
          custom_fields: [
            {
              display_name: 'Job ID',
              variable_name: 'job_id',
              value: jobId,
            },
          ],
        },
      }),
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException(data.message ?? 'Failed to initialize payment');
    }

    return {
      authorization_url: data.data.authorization_url,
      reference,
      access_code: data.data.access_code,
    };
  }

  async verifyPayment(reference: string) {
    const response = await fetch(`${this.paystackBaseUrl}/transaction/verify/${reference}`, {
      headers: this.headers,
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException('Could not verify payment');
    }

    const transaction = data.data;
    const isSuccess = transaction.status === 'success';

    const { error } = await this.supabase
      .from('payments')
      .update({
        status: isSuccess ? 'success' : 'failed',
        paystack_transaction_id: String(transaction.id),
        payment_method: transaction.channel,
        paid_at: isSuccess ? new Date().toISOString() : null,
      })
      .eq('paystack_reference', reference);

    if (error) throw new BadRequestException(error.message);

    return {
      success: isSuccess,
      amount: transaction.amount / 100,
      channel: transaction.channel,
      reference,
    };
  }

  async initializeAcceptanceFee(dto: {
    applicationId: string;
    jobId: string;
    workerId: string;
    workerMedal: string;
    customerId: string;
    customerEmail: string;
  }) {
    if (!dto.customerEmail) {
      throw new BadRequestException('Customer email is required to initialize acceptance fee payment');
    }

    const amount = this.getAcceptanceFee(dto.workerMedal);
    const reference = `ACCEPT_${dto.applicationId.replace(/-/g, '').substring(0, 10)}_${Date.now()}`;

    const { error } = await this.supabase.from('acceptance_fees').insert({
      application_id: dto.applicationId,
      job_id: dto.jobId,
      worker_id: dto.workerId,
      customer_id: dto.customerId,
      worker_medal: dto.workerMedal,
      amount,
      currency: 'GHS',
      paystack_reference: reference,
      status: 'pending',
    });

    if (error) {
      throw new BadRequestException(error.message);
    }

    const response = await fetch(`${this.paystackBaseUrl}/transaction/initialize`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({
        email: dto.customerEmail,
        amount: Math.round(amount * 100),
        currency: 'GHS',
        reference,
        channels: ['card', 'mobile_money'],
        metadata: {
          application_id: dto.applicationId,
          job_id: dto.jobId,
          worker_id: dto.workerId,
          fee_type: 'acceptance_fee',
          worker_medal: dto.workerMedal,
        },
      }),
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException(data.message ?? 'Failed to initialize acceptance fee payment');
    }

    return {
      authorization_url: data.data.authorization_url,
      reference,
      amount,
    };
  }

  async verifyAcceptanceFee(reference: string) {
    const response = await fetch(`${this.paystackBaseUrl}/transaction/verify/${reference}`, {
      headers: this.headers,
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException('Failed to verify acceptance fee payment');
    }

    const transaction = data.data;
    const isSuccess = transaction.status === 'success';

    const updateResult = await this.supabase
      .from('acceptance_fees')
      .update({
        status: isSuccess ? 'paid' : 'failed',
        paystack_transaction_id: String(transaction.id),
        paid_at: isSuccess ? new Date().toISOString() : null,
      })
      .eq('paystack_reference', reference);

    if (updateResult.error) {
      throw new BadRequestException(updateResult.error.message);
    }

    if (!isSuccess) {
      return { success: false };
    }

    const acceptanceRow = await this.supabase
      .from('acceptance_fees')
      .select('application_id, job_id, worker_id, customer_id')
      .eq('paystack_reference', reference)
      .single();

    if (acceptanceRow.error || !acceptanceRow.data) {
      throw new NotFoundException('Acceptance fee record not found');
    }

    const { application_id, job_id, worker_id, customer_id } = acceptanceRow.data as any;

    await this.supabase.from('job_applications').update({ status: 'accepted' }).eq('id', application_id);
    await this.supabase
      .from('job_applications')
      .update({ status: 'declined' })
      .eq('job_id', job_id)
      .neq('id', application_id);

    await this.supabase.from('jobs').update({ status: 'accepted', accepted_worker_id: worker_id }).eq('id', job_id);

    const conversationResult = await this.supabase.from('conversations').insert({
      job_id: job_id,
      customer_id: customer_id,
      worker_id: worker_id,
    });

    if (conversationResult.error) {
      throw new BadRequestException(conversationResult.error.message);
    }

    return { success: true };
  }

  async initializeApplicationFee(dto: { jobId: string; workerId: string; workerEmail: string }) {
    if (!dto.workerEmail) {
      throw new BadRequestException('Worker email is required to initialize application fee payment');
    }

    const reference = `APPLY_${dto.jobId.replace(/-/g, '').substring(0, 10)}_${Date.now()}`;

    const existingApplication = await this.supabase
      .from('job_applications')
      .select('id')
      .eq('job_id', dto.jobId)
      .eq('worker_id', dto.workerId)
      .maybeSingle();

    if (existingApplication.error) {
      throw new BadRequestException(existingApplication.error.message);
    }
    if (existingApplication.data) {
      throw new BadRequestException('You have already applied to this job');
    }

    const { error } = await this.supabase.from('application_fees').insert({
      job_id: dto.jobId,
      worker_id: dto.workerId,
      amount: 5.0,
      currency: 'GHS',
      paystack_reference: reference,
      status: 'pending',
    });

    if (error) {
      throw new BadRequestException(error.message);
    }

    const response = await fetch(`${this.paystackBaseUrl}/transaction/initialize`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({
        email: dto.workerEmail,
        amount: 500,
        currency: 'GHS',
        reference,
        channels: ['card', 'mobile_money'],
        metadata: {
          job_id: dto.jobId,
          worker_id: dto.workerId,
          fee_type: 'application_fee',
        },
      }),
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException(data.message ?? 'Failed to initialize application fee payment');
    }

    return {
      authorization_url: data.data.authorization_url,
      reference,
      amount: 5.0,
    };
  }

  async verifyApplicationFee(reference: string) {
    const response = await fetch(`${this.paystackBaseUrl}/transaction/verify/${reference}`, {
      headers: this.headers,
    });

    const data = await response.json();
    if (!data.status) {
      throw new BadRequestException('Failed to verify application fee payment');
    }

    const transaction = data.data;
    const isSuccess = transaction.status === 'success';

    const feeUpdate = await this.supabase
      .from('application_fees')
      .update({
        status: isSuccess ? 'paid' : 'failed',
        paystack_transaction_id: String(transaction.id),
        paid_at: isSuccess ? new Date().toISOString() : null,
      })
      .eq('paystack_reference', reference);

    if (feeUpdate.error) {
      throw new BadRequestException(feeUpdate.error.message);
    }

    if (!isSuccess) {
      return { success: false };
    }

    const feeRecord = await this.supabase
      .from('application_fees')
      .select('job_id, worker_id')
      .eq('paystack_reference', reference)
      .single();

    if (feeRecord.error || !feeRecord.data) {
      throw new NotFoundException('Application fee record not found');
    }

    const { job_id, worker_id } = feeRecord.data as any;

    const applicationResult = await this.supabase.from('job_applications').insert({
      job_id,
      worker_id,
      status: 'pending',
    });

    if (applicationResult.error) {
      throw new BadRequestException(applicationResult.error.message);
    }

    return {
      success: true,
      transaction_id: transaction.id,
    };
  }

  async getJobPayment(jobId: string) {
    const { data, error } = await this.supabase
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .maybeSingle();

    if (error) throw new BadRequestException(error.message);
    return data;
  }

  async getAllPayments(page = 1, limit = 20) {
    const { data, count, error } = await this.supabase
      .from('payments')
      .select('*, jobs(title, skill_needed), profiles!customer_id(name)', {
        count: 'exact',
      })
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);

    if (error) throw new BadRequestException(error.message);
    return { data, total: count, page, limit };
  }

  private getAcceptanceFee(workerMedal: string) {
    switch (workerMedal.toLowerCase()) {
      case 'gold':
        return 5.0;
      case 'silver':
        return 4.0;
      default:
        return 3.0;
    }
  }
}

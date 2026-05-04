import { Injectable, Inject, BadRequestException } from '@nestjs/common';
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
  }

  private get headers() {
    return {
      Authorization: `Bearer ${this.paystackSecretKey}`,
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

    // Check if payment already exists for this job
    const { data: existing } = await this.supabase
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .eq('status', 'success')
      .maybeSingle();

    if (existing) {
      throw new BadRequestException('This job has already been paid for');
    }

    // Generate unique reference
    const reference = `moka_${jobId.replace(/-/g, '').substring(0, 8)}_${Date.now()}`;

    // Save pending payment to Supabase
    const { error: insertError } = await this.supabase
      .from('payments')
      .upsert({
        job_id: jobId,
        customer_id: customerId,
        worker_id: workerId,
        amount,
        status: 'pending',
        paystack_reference: reference,
      }, { onConflict: 'job_id' });

    if (insertError) throw new Error(insertError.message);

    // Call Paystack initialize API
    const response = await fetch(
      `${this.paystackBaseUrl}/transaction/initialize`,
      {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          email: customerEmail,
          amount: Math.round(amount * 100), // convert to pesewas
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
      },
    );

    const data = await response.json();

    if (!data.status) {
      throw new BadRequestException(
        data.message ?? 'Failed to initialize payment',
      );
    }

    return {
      authorization_url: data.data.authorization_url,
      reference,
      access_code: data.data.access_code,
    };
  }

  async verifyPayment(reference: string) {
    // Call Paystack verify API
    const response = await fetch(
      `${this.paystackBaseUrl}/transaction/verify/${reference}`,
      { headers: this.headers },
    );

    const data = await response.json();

    if (!data.status) {
      throw new BadRequestException('Could not verify payment');
    }

    const transaction = data.data;
    const isSuccess = transaction.status === 'success';

    // Update payment record in Supabase
    const { error } = await this.supabase
      .from('payments')
      .update({
        status: isSuccess ? 'success' : 'failed',
        paystack_transaction_id: String(transaction.id),
        payment_method: transaction.channel,
        paid_at: isSuccess ? new Date().toISOString() : null,
      })
      .eq('paystack_reference', reference);

    if (error) throw new Error(error.message);

    return {
      success: isSuccess,
      amount: transaction.amount / 100, // convert back from pesewas
      channel: transaction.channel,
      reference,
    };
  }

  async getJobPayment(jobId: string) {
    const { data, error } = await this.supabase
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .maybeSingle();

    if (error) throw new Error(error.message);
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

    if (error) throw new Error(error.message);
    return { data, total: count, page, limit };
  }
}

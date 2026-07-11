import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_CLIENT } from '../common/supabase.module';

@Injectable()
export class JobsService {
  constructor(@Inject(SUPABASE_CLIENT) private supabase: SupabaseClient) {}

  async findAll(status?: string, skill?: string, page = 1, limit = 20) {
    let query = this.supabase
      .from('jobs')
      .select('*, profiles!customer_id(name, phone), payments(status, amount)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);

    if (status) query = query.eq('status', status);
    if (skill) query = query.eq('skill_needed', skill);

    const { data, count, error } = await query;
    if (error) throw new Error(error.message);
    return { data, total: count, page, limit };
  }

  async findOne(id: string) {
    const { data, error } = await this.supabase
      .from('jobs')
      .select(`
        *,
        profiles!customer_id(name, phone, email),
        job_applications(*, profiles!worker_id(name, phone, skill, rating)),
        payments(status, amount, payment_method, paid_at),
        ratings(stars, review, profiles!customer_id(name))
      `)
      .eq('id', id)
      .single();
    if (error || !data) throw new NotFoundException('Job not found');
    return data;
  }

  async updateStatus(id: string, status: string) {
    const { data, error } = await this.supabase
      .from('jobs')
      .update({ status })
      .eq('id', id)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return data;
  }

  async delete(id: string) {
    const { error } = await this.supabase
      .from('jobs')
      .delete()
      .eq('id', id);
    if (error) throw new Error(error.message);
    return { success: true };
  }
}

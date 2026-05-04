import { Injectable, Inject } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_CLIENT } from '../common/supabase.module';

@Injectable()
export class AnalyticsService {
  constructor(@Inject(SUPABASE_CLIENT) private supabase: SupabaseClient) {}

  async getOverview() {
    const [
      { count: totalUsers },
      { count: totalWorkers },
      { count: totalCustomers },
      { count: totalJobs },
      { count: openJobs },
      { count: completedJobs },
      { count: onlineWorkers },
      { count: totalRatings },
      { data: revenueData },
    ] = await Promise.all([
      this.supabase.from('profiles').select('*', { count: 'exact', head: true }),
      this.supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'worker'),
      this.supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'customer'),
      this.supabase.from('jobs').select('*', { count: 'exact', head: true }),
      this.supabase.from('jobs').select('*', { count: 'exact', head: true }).eq('status', 'open'),
      this.supabase.from('jobs').select('*', { count: 'exact', head: true }).eq('status', 'completed'),
      this.supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('is_online', true),
      this.supabase.from('ratings').select('*', { count: 'exact', head: true }),
      this.supabase.from('payments').select('amount').eq('status', 'success'),
    ]);

    const totalRevenue = revenueData?.reduce((sum, p) => sum + (p.amount || 0), 0) ?? 0;

    return {
      totalUsers,
      totalWorkers,
      totalCustomers,
      totalJobs,
      openJobs,
      completedJobs,
      onlineWorkers,
      totalRatings,
      totalRevenue: totalRevenue.toFixed(2),
    };
  }

  async getJobsBySkill() {
    const { data, error } = await this.supabase
      .from('jobs')
      .select('skill_needed')
      .not('skill_needed', 'is', null);

    if (error) throw new Error(error.message);

    // Count by skill
    const counts: Record<string, number> = {};
    data.forEach(({ skill_needed }) => {
      counts[skill_needed] = (counts[skill_needed] || 0) + 1;
    });

    return Object.entries(counts)
      .map(([skill, count]) => ({ skill, count }))
      .sort((a, b) => b.count - a.count);
  }

  async getJobsOverTime(days = 30) {
    const from = new Date();
    from.setDate(from.getDate() - days);

    const { data, error } = await this.supabase
      .from('jobs')
      .select('created_at, status')
      .gte('created_at', from.toISOString())
      .order('created_at', { ascending: true });

    if (error) throw new Error(error.message);

    // Group by day
    const grouped: Record<string, { date: string; total: number; completed: number }> = {};
    data.forEach(({ created_at, status }) => {
      const date = new Date(created_at).toISOString().split('T')[0];
      if (!grouped[date]) grouped[date] = { date, total: 0, completed: 0 };
      grouped[date].total++;
      if (status === 'completed') grouped[date].completed++;
    });

    return Object.values(grouped);
  }

  async getUsersOverTime(days = 30) {
    const from = new Date();
    from.setDate(from.getDate() - days);

    const { data, error } = await this.supabase
      .from('profiles')
      .select('created_at, role')
      .gte('created_at', from.toISOString())
      .order('created_at', { ascending: true });

    if (error) throw new Error(error.message);

    const grouped: Record<string, { date: string; customers: number; workers: number }> = {};
    data.forEach(({ created_at, role }) => {
      const date = new Date(created_at).toISOString().split('T')[0];
      if (!grouped[date]) grouped[date] = { date, customers: 0, workers: 0 };
      if (role === 'customer') grouped[date].customers++;
      if (role === 'worker') grouped[date].workers++;
    });

    return Object.values(grouped);
  }

  async getTopWorkers() {
    const { data, error } = await this.supabase
      .from('profiles')
      .select('id, name, skill, rating, is_online')
      .eq('role', 'worker')
      .order('rating', { ascending: false })
      .limit(10);

    if (error) throw new Error(error.message);
    return data;
  }
}

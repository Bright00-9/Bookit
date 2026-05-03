import { Injectable, UnauthorizedException, Inject } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_CLIENT } from '../common/supabase.module';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private jwt: JwtService,
    @Inject(SUPABASE_CLIENT) private supabase: SupabaseClient,
  ) {}

  async login(dto: LoginDto) {
    // Fetch admin from admin_users table
    const { data: admin, error } = await this.supabase
      .from('admin_users')
      .select('*')
      .eq('email', dto.email)
      .single();

    if (error || !admin) throw new UnauthorizedException('Invalid credentials');

    const passwordMatch = await bcrypt.compare(dto.password, admin.password_hash);
    if (!passwordMatch) throw new UnauthorizedException('Invalid credentials');

    const token = this.jwt.sign({
      sub: admin.id,
      email: admin.email,
      role: 'admin',
    });

    return {
      access_token: token,
      admin: { id: admin.id, email: admin.email, name: admin.name },
    };
  }

  async getProfile(adminId: string) {
    const { data } = await this.supabase
      .from('admin_users')
      .select('id, email, name, created_at')
      .eq('id', adminId)
      .single();
    return data;
  }
}

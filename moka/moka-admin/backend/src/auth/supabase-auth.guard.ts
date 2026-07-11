import { Injectable, CanActivate, ExecutionContext, UnauthorizedException, Inject } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_CLIENT } from '../common/supabase.module';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(
    @Inject(SUPABASE_CLIENT) private readonly supabase: SupabaseClient,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authorization = request.headers?.authorization as string | undefined;

    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing authorization token');
    }

    const token = authorization.substring(7).trim();
    const { data, error } = await this.supabase.auth.getUser(token);

    if (error || !data.user) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    request.user = data.user;
    return true;
  }
}

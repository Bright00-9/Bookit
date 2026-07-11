import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { JobsModule } from './jobs/jobs.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { PaymentsModule } from './payments/payments.module';
import { SupabaseModule } from './common/supabase.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env'],
      ignoreEnvFile: false,
    }),
    SupabaseModule,
    AuthModule,
    UsersModule,
    JobsModule,
    AnalyticsModule,
    PaymentsModule,
  ],
})
export class AppModule {}

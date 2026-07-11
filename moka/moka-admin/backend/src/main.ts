import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global validation pipe
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // CORS origin for dashboard or mobile web clients
  const clientOrigin = process.env.BACKEND_CLIENT_ORIGIN || 'http://localhost:3001';
  const allowedOrigins = clientOrigin.split(',').map((origin) => origin.trim());
  app.enableCors({ origin: allowedOrigins, credentials: true });

  // Swagger docs
  const config = new DocumentBuilder()
    .setTitle('Moka Admin API')
    .setDescription('Admin dashboard REST API for Moka app')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = Number(process.env.PORT ?? '3000');
  await app.listen(port);
  console.log('🚀 Moka Admin API running on http://localhost:$port');
  console.log('📚 Swagger docs at http://localhost:$port/api/docs');
}
bootstrap();

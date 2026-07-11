import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global validation pipe
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // CORS for React frontend
  app.enableCors({ origin: 'http://localhost:3001', credentials: true });

  // Swagger docs
  const config = new DocumentBuilder()
    .setTitle('Moka Admin API')
    .setDescription('Admin dashboard REST API for Moka app')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(3000);
  console.log('🚀 Moka Admin API running on http://localhost:3000');
  console.log('📚 Swagger docs at http://localhost:3000/api/docs');
}
bootstrap();

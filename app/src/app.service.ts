import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getInfo() {
    return {
      app: 'nest-api',
      environment: process.env.APP_ENV ?? 'unknown',
      version: process.env.APP_VERSION ?? 'dev',
      hostname: process.env.HOSTNAME ?? 'local',
    };
  }
}

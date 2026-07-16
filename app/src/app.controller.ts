import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getInfo() {
    return this.appService.getInfo();
  }

  @Get('health')
  health() {
    return { status: 'ok', uptime: process.uptime() };
  }

  @Get('load')
  load() {
    // Endpoint para gerar carga de CPU e testar o HPA
    const end = Date.now() + 500;
    while (Date.now() < end) {
      Math.sqrt(Math.random());
    }
    return { status: 'load generated', durationMs: 500 };
  }
}

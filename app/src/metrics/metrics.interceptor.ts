import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { MetricsService } from './metrics.service';

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private readonly metrics: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest();
    // Usa o padrão da rota (ex.: /users/:id) para não explodir a cardinalidade.
    const route: string = req.route?.path ?? req.url;
    const method: string = req.method;
    const end = this.metrics.httpDuration.startTimer({ method, route });

    return next.handle().pipe(
      tap(() => {
        const status = String(http.getResponse().statusCode);
        this.metrics.httpRequests.inc({ method, route, status });
        end({ status });
      }),
    );
  }
}

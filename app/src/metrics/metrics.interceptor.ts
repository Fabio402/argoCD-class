import {
  CallHandler,
  ExecutionContext,
  HttpException,
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

    const record = (status: string) => {
      this.metrics.httpRequests.inc({ method, route, status });
      end({ status });
    };

    return next.handle().pipe(
      tap({
        next: () => record(String(http.getResponse().statusCode)),
        // Na falha o exception filter ainda não escreveu o status na response,
        // então o status vem da própria exceção.
        error: (err: unknown) =>
          record(
            String(err instanceof HttpException ? err.getStatus() : 500),
          ),
      }),
    );
  }
}

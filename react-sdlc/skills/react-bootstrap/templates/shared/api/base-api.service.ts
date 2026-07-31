// DESTINATION: src/shared/api/base-api.service.ts
//
// THE FILE react-slice's *.api.ts templates import. Before this existed, a
// project scaffolded by react-bootstrap and then sliced by react-slice did not
// compile — the slice imported '../../../shared/api/base-api.service' and
// nothing anywhere emitted it.
//
// Two invariants it enforces for every feature api service:
//   1. Every method takes and forwards an AbortSignal, so TanStack Query's
//      cancellation actually reaches the network.
//   2. Nothing above this file ever sees an AxiosError. Failures leave here as
//      ApiError, whose `.detail` is the exhaustively-switchable union.
import type { AxiosRequestConfig } from 'axios';
import { asApiError } from './api-error';
import { httpClient } from './http-client';

export interface RequestOptions {
  signal?: AbortSignal;
  params?: Record<string, string | number | boolean | undefined>;
  headers?: Record<string, string>;
}

function toAxiosConfig(options: RequestOptions | undefined): AxiosRequestConfig {
  if (!options) return {};
  const { signal, params, headers } = options;
  return { signal, params, headers };
}

export abstract class BaseApiService {
  // Written out longhand rather than as a `private readonly` constructor
  // parameter property: tsconfig sets `erasableSyntaxOnly`, and parameter
  // properties emit runtime code, so they are a hard TS1294 error under it.
  private readonly basePath: string;

  protected constructor(basePath: string) {
    this.basePath = basePath;
  }

  protected get<T>(path: string, options?: RequestOptions): Promise<T> {
    return this.request<T>({ method: 'GET', url: this.resolve(path), ...toAxiosConfig(options) });
  }

  protected post<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
    return this.request<T>({
      method: 'POST',
      url: this.resolve(path),
      data: body,
      ...toAxiosConfig(options),
    });
  }

  protected put<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
    return this.request<T>({
      method: 'PUT',
      url: this.resolve(path),
      data: body,
      ...toAxiosConfig(options),
    });
  }

  protected patch<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
    return this.request<T>({
      method: 'PATCH',
      url: this.resolve(path),
      data: body,
      ...toAxiosConfig(options),
    });
  }

  protected delete<T>(path: string, options?: RequestOptions): Promise<T> {
    return this.request<T>({ method: 'DELETE', url: this.resolve(path), ...toAxiosConfig(options) });
  }

  private resolve(path: string): string {
    return `${this.basePath}${path}`;
  }

  private async request<T>(config: AxiosRequestConfig): Promise<T> {
    try {
      const response = await httpClient.request<T>(config);
      return response.data;
    } catch (error) {
      // The single translation point. Rethrowing the mapped error here is what
      // lets every hook and component above stay ignorant of axios.
      throw asApiError(error);
    }
  }
}

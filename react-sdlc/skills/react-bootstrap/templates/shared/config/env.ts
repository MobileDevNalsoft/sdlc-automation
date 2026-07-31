// DESTINATION: src/shared/config/env.ts
//
// The typed seam over runtime config. Parallel to flutter-bootstrap's
// core/config/flavor_config.dart: config is a VALUE, parsed once at startup,
// never a mutable slot anything can write to later.
//
// Reads `window.__ENV__`, populated by public/config.js (committed dev
// defaults) and OVERWRITTEN by the container entrypoint at start — which is
// what lets one built image serve every environment without a rebuild.
//
// Note the shape: window.__ENV__ uses SCREAMING_SNAKE because those keys are
// substituted from environment variables of the same name by the entrypoint.
// That is a WIRE FORMAT, and it gets translated to camelCase exactly once,
// here — the same rule react-slice applies to DTOs. Nothing downstream reads
// `API_BASE_URL`.
//
// SECURITY: nothing here is a secret. Every value lands in the browser and is
// readable from devtools. A backend credential belongs behind the nginx /api/
// proxy (see the docker templates), never in this file.
import { z } from 'zod';

const rawEnvSchema = z.object({
  API_BASE_URL: z.string().min(1, 'API_BASE_URL is required'),
  ENVIRONMENT: z.enum(['development', 'staging', 'production']),
  APP_VERSION: z.string().default('0.0.0'),
  // `coerce` matters: an entrypoint doing envsubst writes STRINGS, so a
  // deployed container would otherwise fail validation on a value that is
  // correct but quoted.
  REQUEST_TIMEOUT_MS: z.coerce.number().int().positive().default(30_000),
  FEATURE_FLAGS: z.record(z.string(), z.boolean()).default({}),
});

export interface AppEnv {
  apiBaseUrl: string;
  environment: 'development' | 'staging' | 'production';
  appVersion: string;
  requestTimeoutMs: number;
  featureFlags: Record<string, boolean>;
}

declare global {
  interface Window {
    __ENV__?: unknown;
  }
}

function readEnv(): AppEnv {
  const raw = typeof window === 'undefined' ? undefined : window.__ENV__;
  const parsed = rawEnvSchema.safeParse(raw ?? {});

  if (!parsed.success) {
    // Fail loudly at startup rather than at the first request. A container
    // that boots and then 404s every call is far harder to diagnose than one
    // that refuses to boot and names the offending field.
    const issues = parsed.error.issues
      .map((issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('; ');
    throw new Error(
      `Invalid runtime config in window.__ENV__ — ${issues}. ` +
        'Check public/config.js (dev) or the container entrypoint (deployed).'
    );
  }

  const data = parsed.data;
  return {
    apiBaseUrl: data.API_BASE_URL,
    environment: data.ENVIRONMENT,
    appVersion: data.APP_VERSION,
    requestTimeoutMs: data.REQUEST_TIMEOUT_MS,
    featureFlags: data.FEATURE_FLAGS,
  };
}

export const env: AppEnv = readEnv();

export const isProduction = (): boolean => env.environment === 'production';

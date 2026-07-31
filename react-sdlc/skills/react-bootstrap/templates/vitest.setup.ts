// Test bootstrap. Runs before every test file.
import '@testing-library/jest-dom/vitest';
import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';

// window.__ENV__ must exist before any module that imports env.ts is loaded,
// because env.ts parses it at module scope and throws on invalid config.
window.__ENV__ = {
  API_BASE_URL: '/api',
  ENVIRONMENT: 'development',
  APP_VERSION: '0.0.0-test',
  REQUEST_TIMEOUT_MS: 1000,
  FEATURE_FLAGS: {},
};

afterEach(() => {
  cleanup();
});

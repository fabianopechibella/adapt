import { defineConfig, devices } from '@playwright/test';

/**
 * Suíte de QA para https://piplanner.io
 * Variáveis de ambiente (todas opcionais):
 *   BASE_URL        URL alvo (padrão: https://piplanner.io)
 *   MAX_PAGES       páginas descobertas pelo crawler (padrão: 20)
 *   PERF_PAGES      páginas medidas em performance (padrão: 5)
 *   PERF_RUNS       repetições por página em performance (padrão: 3)
 *   ALLOW_SUBMIT=1  permite envio real de formulários (padrão: desligado)
 *   CHECK_EXTERNAL=1 verifica também links externos
 */
export const BASE_URL = (process.env.BASE_URL || 'https://piplanner.io').replace(/\/$/, '');

const proxyServer = process.env.HTTPS_PROXY || process.env.https_proxy;
const isLocal = /^https?:\/\/(localhost|127\.0\.0\.1)/.test(BASE_URL);

export default defineConfig({
  testDir: './tests',
  globalSetup: './helpers/global-setup.ts',
  timeout: 90_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  workers: process.env.CI ? 2 : 3,
  retries: 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'reports/html', open: 'never' }],
    ['json', { outputFile: 'reports/results.json' }],
  ],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    ignoreHTTPSErrors: false,
    locale: 'pt-BR',
    ...(proxyServer && !isLocal ? { proxy: { server: proxyServer } } : {}),
  },
  projects: [
    { name: 'desktop-chromium', use: { ...devices['Desktop Chrome'], viewport: { width: 1366, height: 768 } } },
    { name: 'mobile-android', use: { ...devices['Pixel 7'] } },
    // WebKit não está disponível neste ambiente: o iPhone é emulado (viewport, touch, UA) no Chromium.
    { name: 'mobile-ios', use: { ...devices['iPhone 14'], browserName: 'chromium', defaultBrowserType: 'chromium' } },
  ],
});

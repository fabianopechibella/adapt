import fs from 'node:fs';
import path from 'node:path';
import type { Page, TestInfo } from '@playwright/test';

export const REPORT_DIR = path.join(__dirname, '..', 'reports');
export const SITE_MAP_FILE = path.join(REPORT_DIR, 'site-map.json');
// Sessão salva após o único login da execução (contém token: apagada ao fim do run-all.sh).
export const AUTH_STATE_FILE = path.join(REPORT_DIR, '.auth-state.json');

export const env = {
  maxPages: Number(process.env.MAX_PAGES || 20),
  perfPages: Number(process.env.PERF_PAGES || 5),
  perfRuns: Number(process.env.PERF_RUNS || 3),
  allowSubmit: process.env.ALLOW_SUBMIT === '1',
  checkExternal: process.env.CHECK_EXTERNAL === '1',
  // Credenciais só via variável de ambiente: nunca gravar no repositório.
  user: process.env.QA_USER || '',
  pass: process.env.QA_PASS || '',
};

export type FieldInfo = {
  selector: string; tag: string; type: string; name: string;
  required: boolean; maxLength: number; minLength: number; pattern: string; hasLabel: boolean;
};
export type FormInfo = { page: string; index: number; action: string; method: string; fields: FieldInfo[] };
export type PageInfo = { url: string; status: number; title: string };
export type SiteMap = {
  baseURL: string; crawledAt: string;
  pages: PageInfo[]; internalLinks: string[]; externalLinks: string[]; forms: FormInfo[];
  appPages: { url: string; label: string }[];
};

export function loadSiteMap(): SiteMap {
  if (!fs.existsSync(SITE_MAP_FILE)) throw new Error('site-map.json ausente: o global-setup (crawler) não rodou.');
  return JSON.parse(fs.readFileSync(SITE_MAP_FILE, 'utf8'));
}

/** Achado não bloqueante: aparece no relatório sem reprovar o teste. */
export function warn(testInfo: TestInfo, message: string) {
  testInfo.annotations.push({ type: 'warning', description: message });
}

export function attachJson(testInfo: TestInfo, name: string, data: unknown) {
  return testInfo.attach(name, { body: JSON.stringify(data, null, 2), contentType: 'application/json' });
}

/** Coleta erros de runtime (console, exceções, requisições falhas/4xx/5xx) durante a navegação. */
export function collectRuntimeErrors(page: Page) {
  const errors = { console: [] as string[], exceptions: [] as string[], failed: [] as string[], http: [] as string[] };
  page.on('console', (m) => m.type() === 'error' && errors.console.push(m.text()));
  page.on('pageerror', (e) => errors.exceptions.push(e.message));
  page.on('requestfailed', (r) => errors.failed.push(`${r.url()} — ${r.failure()?.errorText}`));
  page.on('response', (r) => r.status() >= 400 && errors.http.push(`${r.status()} ${r.url()}`));
  return errors;
}

export function sameOrigin(url: string, base: string) {
  try { return new URL(url).origin === new URL(base).origin; } catch { return false; }
}

export const slug = (url: string) => new URL(url).pathname.replace(/[^a-z0-9]+/gi, '_').replace(/^_|_$/g, '') || 'home';

/**
 * Bloqueia qualquer escrita na API (POST/PUT/PATCH/DELETE), exceto o login,
 * garantindo que os testes na área logada sejam somente leitura.
 */
export async function readOnlyApi(page: Page, blocked: string[] = []) {
  await page.route('**/api/**', (route) => {
    const r = route.request();
    if (r.method() === 'GET' || r.method() === 'OPTIONS' || r.url().includes('/auth/login')) return route.continue();
    blocked.push(`${r.method()} ${new URL(r.url()).pathname}`);
    return route.abort();
  });
  return blocked;
}

export async function login(page: Page, baseURL: string, user = env.user, pass = env.pass) {
  await page.goto(baseURL + '/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="email"], input[type="email"]', user);
  await page.fill('input[name="password"], input[type="password"]', pass);
  await page.click('form button[type="submit"]');
  await page.waitForURL((u) => !u.pathname.startsWith('/login'), { timeout: 30_000 });
}

/** Espera a tela da SPA terminar de carregar (indicador "Carregando..." some). */
export async function waitAppReady(page: Page, timeout = 30_000) {
  await page.waitForLoadState('domcontentloaded');
  await page.getByText(/^\s*carregando\.{0,3}\s*$/i).first().waitFor({ state: 'hidden', timeout }).catch(() => {});
  await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
}

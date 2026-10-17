import fs from 'node:fs';
import path from 'node:path';
import type { Page, TestInfo } from '@playwright/test';

export const REPORT_DIR = path.join(__dirname, '..', 'reports');
export const SITE_MAP_FILE = path.join(REPORT_DIR, 'site-map.json');

export const env = {
  maxPages: Number(process.env.MAX_PAGES || 20),
  perfPages: Number(process.env.PERF_PAGES || 5),
  perfRuns: Number(process.env.PERF_RUNS || 3),
  allowSubmit: process.env.ALLOW_SUBMIT === '1',
  checkExternal: process.env.CHECK_EXTERNAL === '1',
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

import fs from 'node:fs';
import path from 'node:path';
import { test, expect } from '@playwright/test';
import { attachJson, env, loadSiteMap, REPORT_DIR, warn } from '../../helpers/site';

/**
 * PERFORMANCE — Core Web Vitals e métricas de carregamento em laboratório.
 * Desktop: rede real do runner. Mobile (Android): CPU 4x mais lenta + rede 4G simulada.
 * Cada página é medida PERF_RUNS vezes com cache limpo; usa-se a mediana.
 */
const site = loadSiteMap();
const pages = site.pages.filter((p) => p.status > 0 && p.status < 400).slice(0, env.perfPages);

// Limites do Google (web.dev): [bom, ruim]
const THRESHOLDS = { ttfb: [800, 1800], fcp: [1800, 3000], lcp: [2500, 4000], cls: [0.1, 0.25], tbt: [200, 600] } as const;
type Metric = keyof typeof THRESHOLDS;
const median = (xs: number[]) => { const s = [...xs].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };

test.describe('Performance — Core Web Vitals', () => {
  test.describe.configure({ mode: 'serial' }); // medições sem concorrência entre si

  for (const { url } of pages) {
    test(`métricas: ${new URL(url).pathname}`, async ({ browser }, testInfo) => {
      test.skip(!['desktop-chromium', 'mobile-android'].includes(testInfo.project.name), 'Medido em desktop e Android');
      test.setTimeout(60_000 * env.perfRuns);
      const mobile = testInfo.project.name === 'mobile-android';
      const runs: Record<string, number>[] = [];

      for (let i = 0; i < env.perfRuns; i++) {
        const context = await browser.newContext({ ...testInfo.project.use });
        const page = await context.newPage();
        const cdp = await context.newCDPSession(page);
        await cdp.send('Network.enable');
        await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
        if (mobile) {
          await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
          await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 });
        }
        await page.addInitScript(() => {
          const w = window as any;
          w.__perf = { lcp: 0, cls: 0, tbt: 0 };
          new PerformanceObserver((l) => { for (const e of l.getEntries()) w.__perf.lcp = e.startTime; }).observe({ type: 'largest-contentful-paint', buffered: true });
          new PerformanceObserver((l) => { for (const e of l.getEntries() as any[]) if (!e.hadRecentInput) w.__perf.cls += e.value; }).observe({ type: 'layout-shift', buffered: true });
          new PerformanceObserver((l) => { for (const e of l.getEntries()) w.__perf.tbt += Math.max(0, e.duration - 50); }).observe({ type: 'longtask', buffered: true });
        });
        await page.goto(url, { waitUntil: 'load', timeout: 60_000 });
        await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {});
        await page.waitForTimeout(1000);
        runs.push(await page.evaluate(() => {
          const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
          const res = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
          const fcp = performance.getEntriesByName('first-contentful-paint')[0]?.startTime ?? 0;
          const p = (window as any).__perf;
          return {
            ttfb: nav.responseStart - nav.startTime, fcp, lcp: p.lcp, cls: p.cls, tbt: p.tbt,
            domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime, load: nav.loadEventEnd - nav.startTime,
            requests: res.length + 1,
            transferKB: (res.reduce((s, r) => s + (r.transferSize || 0), 0) + (nav.transferSize || 0)) / 1024,
          };
        }));
        await context.close();
      }

      const result = Object.fromEntries(Object.keys(runs[0]).map((k) => [k, Math.round(median(runs.map((r) => r[k])) * 1000) / 1000]));
      await attachJson(testInfo, 'web-vitals', { url, device: testInfo.project.name, median: result, runs });
      fs.mkdirSync(path.join(REPORT_DIR, 'perf'), { recursive: true });
      fs.writeFileSync(path.join(REPORT_DIR, 'perf', `${testInfo.project.name}-${new URL(url).pathname.replace(/\W+/g, '_') || 'home'}.json`), JSON.stringify({ url, device: testInfo.project.name, median: result }, null, 2));

      if (result.transferKB > 3000) warn(testInfo, `Peso da página ${result.transferKB.toFixed(0)} KB (> 3 MB)`);
      if (result.requests > 100) warn(testInfo, `${result.requests} requisições HTTP (> 100)`);
      for (const m of Object.keys(THRESHOLDS) as Metric[]) {
        const [good, poor] = THRESHOLDS[m];
        if (result[m] > good && result[m] <= poor) warn(testInfo, `${m.toUpperCase()} = ${result[m]} (precisa melhorar; bom ≤ ${good})`);
        expect.soft(result[m], `${m.toUpperCase()} acima do limite "ruim" (${poor})`).toBeLessThanOrEqual(poor);
      }
    });
  }
});

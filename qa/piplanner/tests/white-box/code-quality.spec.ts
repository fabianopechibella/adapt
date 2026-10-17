import { test, expect } from '@playwright/test';
import { attachJson, collectRuntimeErrors, loadSiteMap, warn } from '../../helpers/site';

/**
 * CAIXA BRANCA — inspeciona o código entregue ao navegador (HTML, JS, CSS) e o
 * comportamento interno da aplicação durante a execução.
 */
const site = loadSiteMap();
const pages = site.pages.filter((p) => p.status > 0 && p.status < 400);

test.describe('Caixa branca — qualidade do código em execução', () => {
  for (const { url } of pages) {
    test(`sem exceções JS nem recursos quebrados: ${new URL(url).pathname}`, async ({ page }, testInfo) => {
      const errors = collectRuntimeErrors(page);
      await page.goto(url, { waitUntil: 'load' });
      await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
      await attachJson(testInfo, 'runtime-errors', errors);

      expect(errors.exceptions, 'Exceções JavaScript não tratadas').toEqual([]);
      const ownBroken = errors.http.filter((e) => e.includes(new URL(site.baseURL).host));
      expect.soft(ownBroken, 'Recursos do próprio domínio com HTTP >= 400').toEqual([]);
      if (errors.console.length) warn(testInfo, `${errors.console.length} erro(s) no console: ${errors.console.slice(0, 3).join(' | ')}`);
      if (errors.failed.length) warn(testInfo, `${errors.failed.length} requisição(ões) falharam: ${errors.failed.slice(0, 3).join(' | ')}`);
    });

    test(`estrutura HTML semântica: ${new URL(url).pathname}`, async ({ page }, testInfo) => {
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      const dom = await page.evaluate(() => {
        const ids = Array.from(document.querySelectorAll('[id]')).map((e) => e.id);
        return {
          lang: document.documentElement.lang,
          title: document.title.trim(),
          description: document.querySelector('meta[name="description"]')?.getAttribute('content') || '',
          viewport: document.querySelector('meta[name="viewport"]')?.getAttribute('content') || '',
          h1: document.querySelectorAll('h1').length,
          duplicateIds: [...new Set(ids.filter((id, i) => ids.indexOf(id) !== i))],
          canonical: !!document.querySelector('link[rel="canonical"]'),
          ogTitle: !!document.querySelector('meta[property="og:title"]'),
          favicon: !!document.querySelector('link[rel~="icon"]'),
        };
      });
      await attachJson(testInfo, 'dom-audit', dom);
      expect.soft(dom.title, '<title> preenchido').not.toBe('');
      expect.soft(dom.lang, '<html lang> definido').not.toBe('');
      expect.soft(dom.viewport, 'meta viewport (responsividade)').toContain('width=device-width');
      expect.soft(dom.duplicateIds, 'IDs duplicados no DOM').toEqual([]);
      if (dom.h1 !== 1) warn(testInfo, `Esperado exatamente 1 <h1>, encontrado ${dom.h1}`);
      if (!dom.description) warn(testInfo, 'meta description ausente (SEO)');
      if (!dom.canonical) warn(testInfo, 'link canonical ausente (SEO)');
      if (!dom.ogTitle) warn(testInfo, 'Open Graph ausente (compartilhamento em redes sociais)');
      if (!dom.favicon) warn(testInfo, 'favicon ausente');
    });
  }

  test('cobertura de JS/CSS (código não utilizado na home)', async ({ page, browserName }, testInfo) => {
    test.skip(browserName !== 'chromium' || testInfo.project.name !== 'desktop-chromium', 'Coverage API só no Chromium desktop');
    await Promise.all([page.coverage.startJSCoverage(), page.coverage.startCSSCoverage()]);
    await page.goto(site.baseURL + '/', { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
    const [js, css] = await Promise.all([page.coverage.stopJSCoverage(), page.coverage.stopCSSCoverage()]);

    const jsUsage = js.map((e) => ({ url: e.url, totalBytes: e.source?.length ?? 0, functions: e.functions.length }));
    const cssUsage = css.map((e) => {
      const total = e.text.length;
      const used = e.ranges.reduce((s, r) => s + (r.end - r.start), 0);
      return { url: e.url, totalBytes: total, usedPct: total ? Math.round((used / total) * 100) : 0 };
    });
    const cssTotal = cssUsage.reduce((s, c) => s + c.totalBytes, 0);
    const cssUsed = cssUsage.reduce((s, c) => s + (c.totalBytes * c.usedPct) / 100, 0);
    await attachJson(testInfo, 'coverage', { js: jsUsage, css: cssUsage });
    if (cssTotal && cssUsed / cssTotal < 0.3) warn(testInfo, `Apenas ${Math.round((cssUsed / cssTotal) * 100)}% do CSS é usado na home (considerar CSS crítico / purge)`);
    const jsTotal = jsUsage.reduce((s, j) => s + j.totalBytes, 0);
    if (jsTotal > 1_000_000) warn(testInfo, `JS total na home: ${(jsTotal / 1024).toFixed(0)} KB (considerar code-splitting)`);
  });
});

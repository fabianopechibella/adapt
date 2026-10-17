import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { attachJson, loadSiteMap, warn } from '../../helpers/site';

/** USABILIDADE — acessibilidade automática WCAG 2.1 A/AA com axe-core. */
const site = loadSiteMap();
const pages = site.pages.filter((p) => p.status > 0 && p.status < 400);

test.describe('Usabilidade — acessibilidade (WCAG 2.1 AA)', () => {
  for (const { url } of pages) {
    test(`axe: ${new URL(url).pathname}`, async ({ page }, testInfo) => {
      await page.goto(url, { waitUntil: 'load' });
      await page.waitForLoadState('networkidle', { timeout: 8_000 }).catch(() => {});
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
      const summary = results.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length, helpUrl: v.helpUrl }));
      await attachJson(testInfo, 'axe-violations', summary);
      summary.filter((v) => v.impact === 'moderate' || v.impact === 'minor')
        .forEach((v) => warn(testInfo, `[${v.impact}] ${v.id}: ${v.help} (${v.nodes} elemento(s))`));
      const blocking = summary.filter((v) => v.impact === 'critical' || v.impact === 'serious');
      expect(blocking, 'Violações críticas/graves de acessibilidade').toEqual([]);
    });
  }
});

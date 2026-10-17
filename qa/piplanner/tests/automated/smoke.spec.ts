import { test, expect } from '@playwright/test';
import { loadSiteMap, slug, warn } from '../../helpers/site';

/**
 * TESTES AUTOMATIZADOS (E2E) — smoke/regressão das jornadas principais em
 * desktop, Android e iPhone. Pensado para rodar em pipeline CI/CD a cada deploy.
 */
const site = loadSiteMap();

test.describe('Automatizados — smoke E2E', () => {
  test('home carrega com título e conteúdo principal', async ({ page }, testInfo) => {
    const res = await page.goto('/', { waitUntil: 'domcontentloaded' });
    expect(res?.status()).toBeLessThan(400);
    await expect(page).toHaveTitle(/\S/);
    await expect(page.locator('body')).toBeVisible();
    const main = page.locator('main, [role="main"]');
    if (!(await main.count())) warn(testInfo, 'Sem landmark <main>');
    await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
    await testInfo.attach(`home-${testInfo.project.name}`, { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });
  });

  test('menu principal navega para páginas válidas', async ({ page, isMobile }, testInfo) => {
    await page.goto('/');
    if (isMobile) {
      // Abre o menu hambúrguer, se houver.
      const toggle = page.locator('button[aria-label*="menu" i], button[aria-controls], .navbar-toggler, .hamburger, [class*="menu-toggle" i]').first();
      if (await toggle.isVisible().catch(() => false)) await toggle.click();
    }
    const links = page.locator('header a[href], nav a[href]').filter({ visible: true });
    const count = await links.count();
    if (!count) { warn(testInfo, 'Nenhum link de navegação visível em header/nav'); test.skip(); }
    const hrefs = [...new Set(await links.evaluateAll((as) => as.map((a) => (a as HTMLAnchorElement).href)))]
      .filter((h) => h.startsWith(site.baseURL) && !h.includes('#')).slice(0, 8);
    for (const href of hrefs) {
      const res = await page.goto(href, { waitUntil: 'domcontentloaded' });
      expect.soft(res?.status() ?? 0, href).toBeLessThan(400);
    }
  });

  test('CTAs principais estão visíveis e habilitados', async ({ page }, testInfo) => {
    await page.goto('/');
    const ctas = page.locator('a, button').filter({ hasText: /começ|comec|test|grátis|gratis|cadastr|inscrev|entrar|login|sign|start|try|demo|contato|contact|planej|plan/i }).filter({ visible: true });
    const n = await ctas.count();
    if (!n) { warn(testInfo, 'Nenhum CTA identificado por texto na home'); return; }
    for (let i = 0; i < Math.min(n, 6); i++) {
      const cta = ctas.nth(i);
      await expect.soft(cta).toBeEnabled();
      const box = await cta.boundingBox();
      expect.soft(box && box.width > 0 && box.height > 0, `CTA "${(await cta.innerText()).trim()}" com área clicável`).toBeTruthy();
    }
  });

  test('regressão visual das páginas principais (screenshots de evidência)', async ({ page }, testInfo) => {
    for (const p of site.pages.filter((x) => x.status > 0 && x.status < 400).slice(0, 5)) {
      await page.goto(p.url, { waitUntil: 'load' });
      await page.waitForLoadState('networkidle', { timeout: 8_000 }).catch(() => {});
      await testInfo.attach(`${slug(p.url)}-${testInfo.project.name}`, { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });
    }
  });
});

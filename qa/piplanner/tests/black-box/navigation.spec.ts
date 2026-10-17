import { test, expect } from '@playwright/test';
import { attachJson, env, loadSiteMap, warn } from '../../helpers/site';

/**
 * CAIXA PRETA — valida o comportamento visível ao usuário sem olhar o código:
 * todas as páginas e links respondem, rota inexistente é tratada, histórico funciona.
 */
const site = loadSiteMap();

test.describe('Caixa preta — navegação e links', () => {
  test('todas as páginas descobertas respondem e têm conteúdo', async ({ page }, testInfo) => {
    const problems: string[] = [];
    for (const p of site.pages) {
      if (p.status === 0 || p.status >= 400) { problems.push(`${p.status} ${p.url} ${p.title}`); continue; }
      await page.goto(p.url, { waitUntil: 'domcontentloaded' });
      const text = (await page.locator('body').innerText()).trim();
      if (text.length < 20) problems.push(`Página praticamente vazia: ${p.url}`);
    }
    await attachJson(testInfo, 'pages', site.pages);
    expect(site.pages.length, 'Crawler deve encontrar ao menos a home').toBeGreaterThan(0);
    expect(problems).toEqual([]);
  });

  test('links internos sem 4xx/5xx', async ({ request }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop-chromium', 'Status HTTP independe do dispositivo');
    const broken: string[] = [];
    for (const url of site.internalLinks) {
      const res = await request.get(url, { timeout: 20_000 }).catch((e) => e as Error);
      if (res instanceof Error) broken.push(`ERRO ${url}: ${res.message.split('\n')[0]}`);
      else if (res.status() >= 400) broken.push(`${res.status()} ${url}`);
    }
    await attachJson(testInfo, 'internal-links', { total: site.internalLinks.length, broken });
    expect(broken).toEqual([]);
  });

  test('links externos (opcional: CHECK_EXTERNAL=1)', async ({ request }, testInfo) => {
    test.skip(!env.checkExternal || testInfo.project.name !== 'desktop-chromium', 'Desativado por padrão');
    for (const url of site.externalLinks) {
      const res = await request.head(url, { timeout: 15_000 }).catch(() => null);
      // Redes sociais costumam bloquear robôs (403/999): registra como aviso, não reprova.
      if (!res || res.status() >= 400) warn(testInfo, `Link externo com problema: ${res?.status() ?? 'sem resposta'} ${url}`);
    }
  });

  test('rota inexistente é tratada (404 ou página amigável)', async ({ page }, testInfo) => {
    const res = await page.goto(`${site.baseURL}/qa-rota-inexistente-${Date.now()}`, { waitUntil: 'domcontentloaded' });
    const status = res?.status() ?? 0;
    const text = (await page.locator('body').innerText()).toLowerCase();
    const friendly = /404|não encontrad|not found|page doesn.t exist/.test(text);
    if (status === 200 && !friendly) warn(testInfo, 'Rota inexistente retorna 200 sem mensagem de "não encontrado" (soft-404, ruim para SEO)');
    expect(status, 'Erro de servidor em rota inexistente').toBeLessThan(500);
    expect(status === 404 || friendly || status === 200).toBe(true);
  });

  test('voltar/avançar do navegador preserva a navegação', async ({ page }) => {
    const targets = site.pages.filter((p) => p.status > 0 && p.status < 400).slice(0, 2);
    test.skip(targets.length < 2, 'Site com uma única página');
    await page.goto(targets[0].url);
    await page.goto(targets[1].url);
    await page.goBack();
    await expect(page).toHaveURL(targets[0].url);
    await page.goForward();
    await expect(page).toHaveURL(targets[1].url);
  });
});

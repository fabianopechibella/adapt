import fs from 'node:fs';
import path from 'node:path';
import { test, expect, type Page, type BrowserContext } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { attachJson, AUTH_STATE_FILE, collectRuntimeErrors, env, loadSiteMap, login, readOnlyApi, REPORT_DIR, waitAppReady, warn } from '../../helpers/site';

/**
 * ÁREA LOGADA — exige QA_USER e QA_PASS (variáveis de ambiente).
 * Somente leitura: escritas na API são bloqueadas (helpers/site.ts → readOnlyApi).
 * O servidor limita o login (20 tentativas / 15 min por IP): a sessão é criada uma vez no
 * global-setup e reutilizada; os testes de login rodam só no desktop (~5 tentativas por execução).
 * Cobre caixa preta (login), caixa branca (sessão/autorização), usabilidade e performance por tela.
 */
const site = loadSiteMap();
const hasCreds = !!(env.user && env.pass);
const hasSession = () => fs.existsSync(AUTH_STATE_FILE);
const READY_GOOD_MS = 3_000;
const READY_POOR_MS = 10_000;

test.describe('Área logada — autenticação (caixa preta)', () => {
  test.skip(!hasCreds, 'Defina QA_USER e QA_PASS para testar a área logada');
  test.beforeEach(({}, testInfo) => test.skip(testInfo.project.name !== 'desktop-chromium', 'Regra de login independe do dispositivo (e o servidor limita tentativas)'));

  test('rota protegida sem sessão redireciona para o login', async ({ page }) => {
    const target = site.appPages[0]?.url || `${site.baseURL}/dashboard`;
    await page.goto(target);
    await page.waitForURL(/\/login/, { timeout: 15_000 });
    await expect(page).toHaveURL(/\/login/);
  });

  test('senha fora da política é rejeitada no formulário', async ({ page }) => {
    await page.goto('/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="email"]', env.user);
    await page.fill('input[name="password"]', 'semnumero');
    await page.click('form button[type="submit"]');
    await expect(page).toHaveURL(/\/login/);
  });

  test('credencial inválida não autentica e exibe mensagem', async ({ page }, testInfo) => {
    await page.goto('/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="email"]', env.user);
    await page.fill('input[name="password"]', 'SenhaErrada123');
    const res = page.waitForResponse((r) => r.url().includes('/auth/login'), { timeout: 15_000 }).catch(() => null);
    await page.click('form button[type="submit"]');
    const response = await res;
    const status = response?.status() ?? 0;
    const headers = response ? await response.allHeaders() : {};
    if (!headers['ratelimit-limit'] && !headers['x-ratelimit-limit'] && !headers['retry-after'])
      warn(testInfo, 'Login sem indício de limite de tentativas (headers RateLimit ausentes): risco de força bruta');
    else testInfo.annotations.push({ type: 'info', description: `Limite de tentativas de login: ${headers['ratelimit-policy'] || headers['ratelimit-limit']}` });
    await page.waitForTimeout(1500);
    await expect(page).toHaveURL(/\/login/);
    expect.soft(status, 'API deve responder 401/400 para credencial inválida').toBeGreaterThanOrEqual(400);
    expect.soft(status, 'Credencial inválida não deve gerar erro de servidor').toBeLessThan(500);
  });

  test('e-mail inexistente responde igual a senha errada (sem enumeração de usuários)', async ({ request }, testInfo) => {
    const post = (email: string) => request.post(`${site.baseURL}/api/auth/login`, { data: { email, password: 'SenhaErrada123' } });
    const [known, unknown] = await Promise.all([post(env.user), post(`qa-inexistente-${Date.now()}@example.com`)]);
    const [kb, ub] = [await known.text(), await unknown.text()];
    await attachJson(testInfo, 'respostas', { existente: { status: known.status(), body: kb }, inexistente: { status: unknown.status(), body: ub } });
    if (known.status() !== unknown.status() || kb !== ub) warn(testInfo, 'Respostas diferentes para e-mail existente x inexistente: permite enumerar usuários');
  });

  test('login válido leva ao painel', async ({ page }, testInfo) => {
    await readOnlyApi(page);
    const t0 = Date.now();
    await login(page, site.baseURL);
    await waitAppReady(page);
    const ms = Date.now() - t0;
    testInfo.annotations.push({ type: 'info', description: `Login até painel pronto: ${ms} ms` });
    expect(page.url()).not.toMatch(/\/login/);
    if (ms > READY_GOOD_MS + 2000) warn(testInfo, `Login até painel pronto levou ${ms} ms`);
  });
});

test.describe('Área logada — sessão e autorização (caixa branca)', () => {
  test.skip(!hasCreds, 'Defina QA_USER e QA_PASS');
  test.beforeEach(({}, testInfo) => test.skip(testInfo.project.name !== 'desktop-chromium', 'Independe do dispositivo'));

  test('API protegida recusa acesso sem token', async ({ request }, testInfo) => {
    const endpoints = ['/api/auth/me', '/api/pi-plannings', '/api/risks', '/api/notifications', '/api/strategic-objectives'];
    const open: string[] = [];
    for (const ep of endpoints) {
      const res = await request.get(site.baseURL + ep, { headers: { Accept: 'application/json' } });
      const body = await res.text();
      // SPA pode devolver index.html (200) para rotas desconhecidas: só conta resposta JSON com dados.
      if (res.ok() && !/<html/i.test(body)) open.push(`${res.status()} ${ep}`);
    }
    await attachJson(testInfo, 'endpoints-sem-token', { endpoints, open });
    expect(open, 'Endpoints que devolvem dados sem autenticação').toEqual([]);
  });

  test('armazenamento do navegador após login', async ({ browser }, testInfo) => {
    test.skip(!hasSession(), 'Sessão não criada no global-setup (login falhou?)');
    const context = await browser.newContext({ storageState: AUTH_STATE_FILE });
    const page = await context.newPage();
    await readOnlyApi(page);
    await page.goto(site.appPages[0]?.url || site.baseURL + '/dashboard');
    await waitAppReady(page);
    const storage = await page.evaluate(() => {
      const dump = (s: Storage) => Object.keys(s).map((k) => ({ key: k, size: (s.getItem(k) || '').length, jwt: /eyJ[\w-]+\.[\w-]+\.[\w-]+/.test(s.getItem(k) || '') }));
      return { local: dump(localStorage), session: dump(sessionStorage) };
    });
    const cookies = await page.context().cookies();
    await attachJson(testInfo, 'storage', { ...storage, cookies: cookies.map(({ value, ...c }) => c) });
    const all = [...storage.local, ...storage.session];
    if (all.some((s) => s.jwt)) warn(testInfo, 'Token JWT em localStorage/sessionStorage: acessível a qualquer script (risco em caso de XSS). Preferir cookie HttpOnly');
    if (all.some((s) => /role|permission/i.test(s.key))) warn(testInfo, 'Papel/permissões guardados no navegador: confirmar que o servidor valida a autorização em toda chamada (o cliente pode alterar esses valores)');
    await context.close();
  });
});

test.describe('Área logada — telas (funcional, usabilidade e performance)', () => {
  test.skip(!hasCreds, 'Defina QA_USER e QA_PASS');
  test.skip(!site.appPages.length, 'Nenhuma tela descoberta após o login (ver log do crawler)');

  // Reutiliza a sessão do global-setup: nenhum login extra por tela.
  let context: BrowserContext;
  let page: Page;
  const blockedWrites: string[] = [];
  test.beforeAll(async ({ browser }, testInfo) => {
    test.skip(!hasSession(), 'Sessão não criada no global-setup (login falhou?)');
    context = await browser.newContext({ ...testInfo.project.use, storageState: AUTH_STATE_FILE });
    page = await context.newPage();
    await readOnlyApi(page, blockedWrites);
  });
  test.afterAll(async () => context?.close());

  for (const { url, label } of site.appPages) {
    test(`${label || new URL(url).pathname} (${new URL(url).pathname})`, async ({}, testInfo) => {
      const errors = collectRuntimeErrors(page);
      const api: { url: string; status: number; ms: number }[] = [];
      const onResponse = async (r: import('@playwright/test').Response) => {
        if (!r.url().includes('/api/')) return;
        const t = r.request().timing();
        api.push({ url: `${r.request().method()} ${new URL(r.url()).pathname}`, status: r.status(), ms: Math.round(t.responseEnd > 0 ? t.responseEnd : -1) });
      };
      page.on('response', onResponse);

      const t0 = Date.now();
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await waitAppReady(page, READY_POOR_MS + 5_000);
      const readyMs = Date.now() - t0;
      page.off('response', onResponse);

      const stuck = await page.getByText(/^\s*carregando\.{0,3}\s*$/i).first().isVisible().catch(() => false);
      const dom = await page.evaluate(() => ({
        overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
        heading: (document.querySelector('main h1, main h2, h1, h2')?.textContent || '').trim(),
        textLength: (document.querySelector('main') || document.body).innerText.trim().length,
      }));
      const axe = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
      const blocking = axe.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious').map((v) => `${v.id} (${v.nodes.length})`);
      const api5xx = api.filter((a) => a.status >= 500);
      const api4xx = api.filter((a) => a.status >= 400 && a.status < 500);
      const slowApi = api.filter((a) => a.ms > 2000);

      const result = { url, label, device: testInfo.project.name, readyMs, stuck, ...dom, api, axe: blocking, exceptions: errors.exceptions, console: errors.console };
      await attachJson(testInfo, 'tela', result);
      fs.mkdirSync(path.join(REPORT_DIR, 'app'), { recursive: true });
      fs.writeFileSync(path.join(REPORT_DIR, 'app', `${testInfo.project.name}-${new URL(url).pathname.replace(/\W+/g, '_')}.json`), JSON.stringify(result, null, 2));

      // Funcional
      expect.soft(page.url(), 'Sessão perdida: redirecionou ao login').not.toMatch(/\/login/);
      expect.soft(stuck, `Tela presa em "Carregando..." após ${readyMs} ms`).toBe(false);
      expect.soft(errors.exceptions, 'Exceções JavaScript').toEqual([]);
      expect.soft(api5xx.map((a) => `${a.status} ${a.url}`), 'Erros 5xx na API').toEqual([]);
      if (api4xx.length) warn(testInfo, `API 4xx: ${api4xx.map((a) => `${a.status} ${a.url}`).join(', ')}`);
      if (dom.textLength < 30) warn(testInfo, 'Tela com pouco ou nenhum conteúdo (estado vazio sem orientação?)');
      if (!dom.heading) warn(testInfo, 'Tela sem título (h1/h2)');
      if (errors.console.length) warn(testInfo, `${errors.console.length} erro(s) no console: ${errors.console.slice(0, 2).join(' | ').slice(0, 200)}`);
      // Usabilidade
      expect.soft(dom.overflow, 'Rolagem horizontal na tela').toBeLessThanOrEqual(1);
      expect.soft(blocking, 'Violações de acessibilidade críticas/graves').toEqual([]);
      // Performance
      if (readyMs > READY_GOOD_MS) warn(testInfo, `Tela pronta em ${readyMs} ms (meta ≤ ${READY_GOOD_MS} ms)`);
      slowApi.forEach((a) => warn(testInfo, `API lenta: ${a.url} ${a.ms} ms`));
      expect.soft(readyMs, `Tempo até a tela ficar pronta (limite ${READY_POOR_MS} ms)`).toBeLessThanOrEqual(READY_POOR_MS);
    });
  }

  test('nenhuma tela tentou gravar dados durante a navegação', async ({}, testInfo) => {
    if (blockedWrites.length) warn(testInfo, `Escritas bloqueadas pelo modo somente leitura: ${[...new Set(blockedWrites)].join(', ')}`);
  });

  test('grupos do menu lateral são acessíveis por teclado', async ({ isMobile }, testInfo) => {
    test.skip(isMobile, 'Critério desktop');
    await page.goto(site.appPages[0].url);
    await waitAppReady(page);
    const groups = page.locator('[data-sidebar="group-label"]');
    await groups.first().waitFor({ timeout: 10_000 }).catch(() => {});
    const audit = await groups.evaluateAll((els) => els.map((e) => ({
      text: (e as HTMLElement).innerText.trim(),
      focusable: (e as HTMLElement).tabIndex >= 0 || !!e.querySelector('button, a[href]'),
      role: e.getAttribute('role') || e.querySelector('button')?.tagName.toLowerCase() || '',
      expanded: e.getAttribute('aria-expanded') ?? e.querySelector('[aria-expanded]')?.getAttribute('aria-expanded') ?? null,
    })));
    await attachJson(testInfo, 'menu-groups', audit);
    test.skip(!audit.length, 'Menu sem grupos recolhíveis');
    expect.soft(audit.filter((g) => !g.focusable).map((g) => g.text), 'Grupos do menu sem foco por teclado (WCAG 2.1.1)').toEqual([]);
    expect.soft(audit.filter((g) => g.expanded === null).map((g) => g.text), 'Grupos do menu sem aria-expanded (WCAG 4.1.2)').toEqual([]);
  });

  test('menu lateral abre e fecha no mobile', async ({ isMobile }) => {
    test.skip(!isMobile, 'Critério mobile');
    await page.goto(site.appPages[0].url);
    await waitAppReady(page);
    const toggle = page.getByRole('button', { name: /alternar menu|menu/i }).first();
    await expect(toggle).toBeVisible();
    await toggle.click();
    await expect(page.locator('[data-sidebar="content"], aside nav').first()).toBeVisible();
  });
});

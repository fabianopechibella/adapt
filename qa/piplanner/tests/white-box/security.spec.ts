import { test, expect } from '@playwright/test';
import { attachJson, loadSiteMap, sameOrigin, warn } from '../../helpers/site';

/**
 * CAIXA BRANCA — segurança da camada web: headers HTTP, cookies, conteúdo misto,
 * source maps, segredos no bundle e arquivos sensíveis expostos.
 * Somente leitura: nenhuma tentativa de invasão é feita.
 */
const site = loadSiteMap();
test.describe.configure({ mode: 'serial' });

test.describe('Caixa branca — segurança', () => {
  test.beforeEach(({}, testInfo) => test.skip(testInfo.project.name !== 'desktop-chromium', 'Independe do dispositivo: roda só no desktop'));

  test('headers de segurança HTTP na home', async ({ request }, testInfo) => {
    const res = await request.get(site.baseURL + '/');
    const h = res.headers();
    await attachJson(testInfo, 'headers', h);
    const https = site.baseURL.startsWith('https');
    const checks: [string, boolean][] = [
      ['Strict-Transport-Security (HSTS)', !https || !!h['strict-transport-security']],
      ['Content-Security-Policy', !!h['content-security-policy']],
      ['X-Content-Type-Options: nosniff', (h['x-content-type-options'] || '').includes('nosniff')],
      ['Proteção contra clickjacking (X-Frame-Options ou CSP frame-ancestors)', !!h['x-frame-options'] || (h['content-security-policy'] || '').includes('frame-ancestors')],
      ['Referrer-Policy', !!h['referrer-policy']],
    ];
    const missing = checks.filter(([, ok]) => !ok).map(([name]) => name);
    missing.forEach((m) => warn(testInfo, `Header ausente: ${m}`));
    if (h['server'] && /\d/.test(h['server'])) warn(testInfo, `Header Server expõe versão: ${h['server']}`);
    if (h['x-powered-by']) warn(testInfo, `Header X-Powered-By expõe tecnologia: ${h['x-powered-by']}`);
    expect(res.status()).toBeLessThan(400);
  });

  test('cookies com flags Secure / HttpOnly / SameSite', async ({ page, context }, testInfo) => {
    await page.goto(site.baseURL + '/', { waitUntil: 'networkidle' }).catch(() => {});
    const cookies = (await context.cookies()).filter((c) => sameOrigin(`https://${c.domain.replace(/^\./, '')}`, site.baseURL.replace('http:', 'https:')));
    await attachJson(testInfo, 'cookies', cookies.map(({ value, ...c }) => c));
    for (const c of cookies) {
      if (site.baseURL.startsWith('https') && !c.secure) warn(testInfo, `Cookie "${c.name}" sem Secure`);
      if (c.sameSite === 'None' && !c.secure) warn(testInfo, `Cookie "${c.name}" SameSite=None sem Secure`);
      if (/sess|token|auth/i.test(c.name)) expect.soft(c.httpOnly, `Cookie de sessão "${c.name}" deve ser HttpOnly`).toBe(true);
    }
  });

  test('sem conteúdo misto (HTTP dentro de HTTPS)', async ({ page }) => {
    test.skip(!site.baseURL.startsWith('https'), 'Alvo não é HTTPS');
    const insecure: string[] = [];
    page.on('request', (r) => r.url().startsWith('http://') && insecure.push(r.url()));
    for (const p of site.pages.slice(0, 10)) await page.goto(p.url, { waitUntil: 'load' }).catch(() => {});
    expect(insecure, 'Recursos carregados via HTTP').toEqual([]);
  });

  test('segredos e source maps no código JS entregue', async ({ page, request }, testInfo) => {
    const scripts = new Set<string>();
    page.on('response', (r) => r.request().resourceType() === 'script' && sameOrigin(r.url(), site.baseURL) && scripts.add(r.url()));
    await page.goto(site.baseURL + '/', { waitUntil: 'networkidle' }).catch(() => {});
    const inline = await page.$$eval('script:not([src])', (s) => s.map((e) => e.textContent || '').join('\n'));

    const patterns: [string, RegExp][] = [
      ['Chave privada', /-----BEGIN (RSA |EC )?PRIVATE KEY-----/],
      ['AWS Access Key', /AKIA[0-9A-Z]{16}/],
      ['Stripe secret key', /sk_live_[0-9a-zA-Z]{20,}/],
      ['Token GitHub', /gh[pousr]_[A-Za-z0-9]{36}/],
      ['Slack token', /xox[baprs]-[A-Za-z0-9-]{10,}/],
      // Literal sem espaços e com dígito: ignora mensagens ("Erro ao redefinir senha:") e rótulos i18n ("password": "Senha").
      ['Senha hardcoded', /\b(password|passwd|pwd|senha)["']?\s*[:=]\s*["'](?=[^"'\s]*\d)[^"'\s,;)\/]{6,}["']/i],
    ];
    const findings: string[] = [];
    const maps: string[] = [];
    const sources = [{ url: 'inline', body: inline }];
    for (const url of scripts) {
      const res = await request.get(url);
      sources.push({ url, body: await res.text() });
      const mapRes = await request.get(url + '.map');
      if (mapRes.ok() && (await mapRes.text()).includes('"mappings"')) maps.push(url + '.map');
    }
    for (const { url, body } of sources) for (const [name, re] of patterns) if (re.test(body)) findings.push(`${name} em ${url}`);
    if (sources.some((s) => /AIza[0-9A-Za-z_-]{35}/.test(s.body))) warn(testInfo, 'Chave de API Google/Firebase no bundle (é pública por design; confirme restrições de domínio e regras do Firestore)');
    maps.forEach((m) => warn(testInfo, `Source map público: ${m}`));
    await attachJson(testInfo, 'secret-scan', { scripts: [...scripts], findings, sourceMaps: maps });
    expect(findings, 'Segredos encontrados no código entregue ao navegador').toEqual([]);
  });

  test('arquivos sensíveis não expostos', async ({ request }) => {
    const exposed: string[] = [];
    for (const p of ['/.git/HEAD', '/.env', '/.DS_Store', '/wp-config.php.bak', '/server-status', '/config.json.bak']) {
      const res = await request.get(site.baseURL + p, { maxRedirects: 0 });
      const body = res.ok() ? await res.text() : '';
      // SPAs costumam devolver index.html com 200 para qualquer rota: só conta se não for HTML.
      if (res.ok() && !/<html/i.test(body) && body.length > 0) exposed.push(p);
    }
    expect(exposed).toEqual([]);
  });
});

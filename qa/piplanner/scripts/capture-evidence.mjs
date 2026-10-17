// Captura evidências visuais para o relatório executivo: violações de acessibilidade
// destacadas em vermelho (público e área logada).
// Uso: QA_USER=... QA_PASS=... node scripts/capture-evidence.mjs
import { chromium } from 'playwright';
import AxeBuilder from '@axe-core/playwright';
import fs from 'node:fs';

const BASE = (process.env.BASE_URL || 'https://piplanner.io').replace(/\/$/, '');
const OUT = new URL('../evidencias/', import.meta.url).pathname;
const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined;
const browser = await chromium.launch({ proxy });
const summary = {};

async function highlight(page, rules, file, label) {
  const res = await new AxeBuilder({ page }).withRules(rules).analyze();
  const targets = res.violations.flatMap((v) => v.nodes.map((n) => n.target[0]));
  await page.evaluate(({ targets, label }) => {
    for (const sel of targets) document.querySelectorAll(sel).forEach((el) => { el.style.outline = '3px solid #d00'; el.style.outlineOffset = '2px'; });
    const tag = document.createElement('div');
    tag.textContent = label;
    tag.style.cssText = 'position:fixed;bottom:12px;right:12px;z-index:99999;background:#d00;color:#fff;font:600 14px system-ui;padding:8px 12px;border-radius:6px';
    document.body.appendChild(tag);
  }, { targets, label: `${label}: ${targets.length} elemento(s)` });
  await page.screenshot({ path: OUT + file });
  summary[file] = { rules, count: targets.length };
}

// 1) Público, desktop
const pub = await (await browser.newContext({ viewport: { width: 1366, height: 768 } })).newPage();
await pub.goto(BASE + '/login', { waitUntil: 'networkidle' });
await highlight(pub, ['button-name'], '01-login-botao-sem-nome.png', 'Botão sem nome acessível');

// 3) Área logada (1 login)
if (process.env.QA_USER && process.env.QA_PASS) {
  const app = await (await browser.newContext({ viewport: { width: 1366, height: 768 } })).newPage();
  await app.route('**/api/**', (r) => (['GET', 'OPTIONS'].includes(r.request().method()) || r.request().url().includes('/auth/login') ? r.continue() : r.abort()));
  await app.goto(BASE + '/login', { waitUntil: 'networkidle' });
  await app.fill('input[name="email"]', process.env.QA_USER);
  await app.fill('input[name="password"]', process.env.QA_PASS);
  await app.click('form button[type="submit"]');
  await app.waitForURL((u) => !u.pathname.startsWith('/login'), { timeout: 30000 });
  const ready = async (path) => {
    await app.goto(BASE + path, { waitUntil: 'domcontentloaded' });
    await app.getByText(/^\s*carregando\.{0,3}\s*$/i).first().waitFor({ state: 'hidden', timeout: 20000 }).catch(() => {});
    await app.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
  };
  await ready('/RolesPermissions');
  await highlight(app, ['button-name'], '04-papeis-permissoes-botoes-sem-nome.png', 'Botões sem nome acessível');
  await ready('/UserManagement');
  await highlight(app, ['button-name', 'color-contrast'], '05-gestao-usuarios.png', 'Botões sem nome e baixo contraste');
  await ready('/Dashboard');
  await app.evaluate(() => document.querySelectorAll('[data-sidebar="group-label"]').forEach((el) => { el.style.outline = '3px solid #d00'; }));
  await app.screenshot({ path: OUT + '06-menu-sem-teclado.png' });
}
fs.writeFileSync(OUT + 'evidencias.json', JSON.stringify(summary, null, 2));
await browser.close();
console.log(summary);

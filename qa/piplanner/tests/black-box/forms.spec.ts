import { test, expect, type Page } from '@playwright/test';
import { attachJson, env, loadSiteMap, warn, type FieldInfo, type FormInfo } from '../../helpers/site';

/**
 * CAIXA PRETA — formulários com técnicas clássicas de projeto de casos de teste:
 *  - Partição de equivalência (e-mails válidos x inválidos)
 *  - Análise de valor-limite (maxlength / minlength)
 *  - Campos obrigatórios em branco
 *  - Entrada maliciosa (XSS refletido) — sem envio, a menos que ALLOW_SUBMIT=1
 * Por padrão NADA é enviado ao servidor (evita criar leads/cadastros reais).
 */
const site = loadSiteMap();
const forms = site.forms.filter((f) => f.fields.length > 0);

const formLocator = (page: Page, f: FormInfo) => page.locator('form').nth(f.index);
const validity = (page: Page, f: FormInfo, field: FieldInfo) =>
  formLocator(page, f).locator(field.selector).first().evaluate((el: HTMLInputElement) => el.checkValidity());

test.describe('Caixa preta — formulários', () => {
  test('inventário de formulários', async ({}, testInfo) => {
    await attachJson(testInfo, 'forms', forms);
    if (!forms.length) warn(testInfo, 'Nenhum formulário encontrado nas páginas públicas (login/cadastro podem estar em outro domínio ou exigir credenciais)');
    forms.flatMap((f) => f.fields.filter((x) => !x.hasLabel).map((x) => `${f.page} → campo "${x.name}" sem label acessível`))
      .forEach((m) => warn(testInfo, m));
  });

  for (const f of forms) {
    const where = `${new URL(f.page).pathname} form#${f.index}`;

    test(`campos obrigatórios bloqueiam envio vazio: ${where}`, async ({ page }) => {
      const required = f.fields.filter((x) => x.required);
      test.skip(!required.length, 'Formulário sem campos required declarados');
      await page.goto(f.page);
      const formValid = await formLocator(page, f).evaluate((el: HTMLFormElement) => el.checkValidity());
      expect(formValid, 'Formulário vazio não deve ser válido').toBe(false);
    });

    test(`partição de equivalência em e-mail: ${where}`, async ({ page }) => {
      const email = f.fields.find((x) => x.type === 'email');
      test.skip(!email, 'Sem campo type=email');
      await page.goto(f.page);
      const input = formLocator(page, f).locator(email!.selector).first();
      for (const bad of ['abc', 'a@', '@dominio.com', 'a b@c.com', 'teste@@x.com']) {
        await input.fill(bad);
        expect.soft(await validity(page, f, email!), `"${bad}" deveria ser inválido`).toBe(false);
      }
      for (const good of ['qa.teste@example.com', 'nome+tag@empresa.com.br']) {
        await input.fill(good);
        expect.soft(await validity(page, f, email!), `"${good}" deveria ser válido`).toBe(true);
      }
    });

    test(`valores-limite (maxlength/minlength): ${where}`, async ({ page }, testInfo) => {
      const bounded = f.fields.filter((x) => ['text', 'textarea', 'email', 'tel', 'search', 'password'].includes(x.type) && (x.maxLength > 0 || x.minLength > 0));
      const texts = f.fields.filter((x) => ['text', 'textarea'].includes(x.type) && x.maxLength <= 0);
      texts.forEach((x) => warn(testInfo, `Campo "${x.name}" sem maxlength (entrada ilimitada)`));
      test.skip(!bounded.length, 'Sem limites declarados');
      await page.goto(f.page);
      for (const x of bounded) {
        const input = formLocator(page, f).locator(x.selector).first();
        if (x.maxLength > 0) {
          await input.fill('');
          await input.pressSequentially('a'.repeat(x.maxLength + 1), { delay: 0 });
          expect.soft((await input.inputValue()).length, `${x.name}: limite máximo ${x.maxLength}`).toBeLessThanOrEqual(x.maxLength);
        }
        if (x.minLength > 1) {
          await input.fill('a'.repeat(x.minLength - 1));
          expect.soft(await validity(page, f, x), `${x.name}: abaixo do mínimo ${x.minLength} deve ser inválido`).toBe(false);
          await input.fill('a'.repeat(x.minLength));
          if (x.type === 'text') expect.soft(await validity(page, f, x), `${x.name}: no mínimo deve ser válido`).toBe(true);
        }
      }
    });

    test(`entrada maliciosa não executa script: ${where}`, async ({ page }) => {
      const payload = `"><img src=x onerror="window.__xss=1">`;
      let dialog = false;
      page.on('dialog', (d) => { dialog = true; return d.dismiss(); });
      await page.goto(f.page);
      const form = formLocator(page, f);
      for (const x of f.fields.filter((x) => ['text', 'textarea', 'search'].includes(x.type))) await form.locator(x.selector).first().fill(payload);
      if (env.allowSubmit) {
        const resPromise = page.waitForResponse(() => true, { timeout: 10_000 }).catch(() => null);
        await form.evaluate((el: HTMLFormElement) => el.requestSubmit());
        const res = await resPromise;
        expect.soft(res?.status() ?? 0, 'Servidor não deve responder 5xx a entrada maliciosa').toBeLessThan(500);
        await page.waitForLoadState('load').catch(() => {});
      }
      expect(await page.evaluate(() => (window as any).__xss)).toBeUndefined();
      expect(dialog).toBe(false);
    });
  }
});

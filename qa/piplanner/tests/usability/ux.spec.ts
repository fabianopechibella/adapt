import { test, expect } from '@playwright/test';
import { attachJson, loadSiteMap, warn } from '../../helpers/site';

/** USABILIDADE — responsividade, alvos de toque, legibilidade e navegação por teclado. */
const site = loadSiteMap();
const pages = site.pages.filter((p) => p.status > 0 && p.status < 400).slice(0, 10);

test.describe('Usabilidade — UX web e mobile', () => {
  for (const { url } of pages) {
    const path = new URL(url).pathname;

    test(`layout responsivo sem rolagem horizontal: ${path}`, async ({ page }) => {
      await page.goto(url, { waitUntil: 'load' });
      const overflow = await page.evaluate(() => {
        const w = document.documentElement.clientWidth;
        const offenders = Array.from(document.querySelectorAll('body *'))
          .filter((el) => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > w + 1; })
          .slice(0, 5).map((el) => `${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}.${(el.className?.toString() || '').split(' ')[0]}`);
        return { scroll: document.documentElement.scrollWidth - w, offenders };
      });
      expect(overflow.scroll, `Rolagem horizontal de ${overflow.scroll}px. Elementos: ${overflow.offenders.join(', ')}`).toBeLessThanOrEqual(1);
    });

    test(`alvos de toque e legibilidade: ${path}`, async ({ page, isMobile }, testInfo) => {
      test.skip(!isMobile, 'Critério mobile');
      await page.goto(url, { waitUntil: 'load' });
      const audit = await page.evaluate(() => {
        const visible = (el: Element) => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden'; };
        const targets = Array.from(document.querySelectorAll('a, button, input, select, textarea, [role="button"]')).filter(visible);
        const small = (min: number) => targets.filter((el) => {
          const r = el.getBoundingClientRect();
          // Links dentro de parágrafos são isentos pela WCAG 2.5.8.
          return (r.width < min || r.height < min) && !(el.tagName === 'A' && el.closest('p, li'));
        }).map((el) => `${el.tagName.toLowerCase()} "${(el.textContent || (el as HTMLInputElement).placeholder || '').trim().slice(0, 30)}"`);
        const tinyText = Array.from(document.querySelectorAll('p, li, span, a, label, td')).filter(visible)
          .filter((el) => el.childNodes.length && Array.from(el.childNodes).some((n) => n.nodeType === 3 && n.textContent!.trim()))
          .filter((el) => parseFloat(getComputedStyle(el).fontSize) < 12).length;
        const inputsZoom = Array.from(document.querySelectorAll('input, select, textarea')).filter(visible)
          .filter((el) => parseFloat(getComputedStyle(el).fontSize) < 16).length;
        return { total: targets.length, below24: small(24), below44: small(44).length, tinyText, inputsZoom };
      });
      await attachJson(testInfo, 'touch-audit', audit);
      if (audit.below44) warn(testInfo, `${audit.below44} alvo(s) de toque abaixo de 44px (recomendação Apple/Material)`);
      if (audit.tinyText) warn(testInfo, `${audit.tinyText} elemento(s) de texto com fonte < 12px`);
      if (audit.inputsZoom) warn(testInfo, `${audit.inputsZoom} campo(s) com fonte < 16px: iOS dá zoom ao focar`);
      expect.soft(audit.below24, 'Alvos de toque < 24px (WCAG 2.2 — 2.5.8)').toEqual([]);
    });
  }

  test('navegação por teclado com foco visível', async ({ page, isMobile }, testInfo) => {
    test.skip(isMobile, 'Critério desktop');
    await page.goto('/', { waitUntil: 'load' });
    const steps: { tag: string; text: string; visibleFocus: boolean }[] = [];
    for (let i = 0; i < 15; i++) {
      await page.keyboard.press('Tab');
      steps.push(await page.evaluate(() => {
        const el = document.activeElement as HTMLElement | null;
        if (!el || el === document.body) return { tag: 'body', text: '', visibleFocus: false };
        const s = getComputedStyle(el);
        const visibleFocus = (s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0) || s.boxShadow !== 'none' || el.matches(':focus-visible');
        return { tag: el.tagName.toLowerCase(), text: (el.innerText || el.getAttribute('aria-label') || '').trim().slice(0, 40), visibleFocus };
      }));
    }
    await attachJson(testInfo, 'tab-order', steps);
    const focused = steps.filter((s) => s.tag !== 'body');
    expect(focused.length, 'Tab deve percorrer elementos interativos').toBeGreaterThan(0);
    const noRing = focused.filter((s) => !s.visibleFocus);
    if (noRing.length) warn(testInfo, `${noRing.length} elemento(s) focados sem indicador visível`);
    const skipLink = /pular|skip/i.test(focused[0]?.text || '');
    if (!skipLink) warn(testInfo, 'Sem link "pular para o conteúdo" no primeiro Tab');
  });

  test('imagens com texto alternativo', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop-chromium', 'Independe do dispositivo');
    const missing: string[] = [];
    for (const { url } of pages) {
      await page.goto(url, { waitUntil: 'load' });
      missing.push(...(await page.$$eval('img:not([alt])', (imgs) => imgs.map((i) => (i as HTMLImageElement).src))).map((s) => `${url} → ${s}`));
    }
    expect.soft(missing, 'Imagens sem atributo alt').toEqual([]);
  });
});

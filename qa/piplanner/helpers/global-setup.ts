import fs from 'node:fs';
import { chromium, type FullConfig } from '@playwright/test';
import { env, REPORT_DIR, SITE_MAP_FILE, sameOrigin, type FormInfo, type SiteMap } from './site';

/**
 * Crawler (BFS) executado uma única vez antes dos testes: descobre páginas internas,
 * links e formulários do site. Todos os testes leem reports/site-map.json, então a
 * suíte se adapta automaticamente às funcionalidades existentes no site.
 */
export default async function globalSetup(config: FullConfig) {
  const use = config.projects[0].use;
  const baseURL = String(use.baseURL);
  fs.mkdirSync(REPORT_DIR, { recursive: true });

  const browser = await chromium.launch({ proxy: use.proxy });
  const page = await browser.newPage({ locale: 'pt-BR' });
  const map: SiteMap = { baseURL, crawledAt: new Date().toISOString(), pages: [], internalLinks: [], externalLinks: [], forms: [] };
  const queue = [baseURL + '/'];
  const seen = new Set<string>(queue);
  const internal = new Set<string>();
  const external = new Set<string>();

  while (queue.length && map.pages.length < env.maxPages) {
    const url = queue.shift()!;
    let status = 0;
    try {
      const res = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
      await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
      status = res?.status() ?? 0;
    } catch (e) {
      map.pages.push({ url, status: 0, title: `ERRO: ${(e as Error).message.split('\n')[0]}` });
      continue;
    }
    // Ignora redirecionamentos para fora do domínio (ex.: login SSO).
    if (!sameOrigin(page.url(), baseURL)) continue;
    map.pages.push({ url, status, title: await page.title() });

    const hrefs = await page.$$eval('a[href]', (as) => as.map((a) => (a as HTMLAnchorElement).href));
    for (const raw of hrefs) {
      if (!/^https?:/.test(raw)) continue;
      const clean = raw.split('#')[0];
      if (sameOrigin(clean, baseURL)) {
        internal.add(clean);
        const isAsset = /\.(pdf|png|jpe?g|gif|svg|webp|zip|mp4|docx?|xlsx?)$/i.test(new URL(clean).pathname);
        if (!seen.has(clean) && !isAsset) { seen.add(clean); queue.push(clean); }
      } else external.add(clean);
    }

    const forms: Omit<FormInfo, 'page'>[] = await page.$$eval('form', (fs) =>
      fs.map((f, index) => ({
        index,
        action: (f as HTMLFormElement).action,
        method: (f as HTMLFormElement).method,
        fields: Array.from(f.querySelectorAll('input, textarea, select'))
          .filter((el) => !['hidden', 'submit', 'button', 'reset', 'image'].includes((el as HTMLInputElement).type))
          .map((el, i) => {
            const e = el as HTMLInputElement;
            const id = e.id;
            return {
              selector: id ? `#${CSS.escape(id)}` : e.name ? `[name="${e.name}"]` : `${e.tagName.toLowerCase()}:nth-of-type(${i + 1})`,
              tag: e.tagName.toLowerCase(), type: e.type, name: e.name || id,
              required: e.required, maxLength: e.maxLength ?? -1, minLength: e.minLength ?? -1, pattern: e.pattern || '',
              hasLabel: !!(e.labels?.length || e.getAttribute('aria-label') || e.getAttribute('aria-labelledby')),
            };
          }),
      })),
    );
    map.forms.push(...forms.map((f) => ({ ...f, page: url })));
  }

  map.internalLinks = [...internal];
  map.externalLinks = [...external];
  fs.writeFileSync(SITE_MAP_FILE, JSON.stringify(map, null, 2));
  console.log(`[crawler] ${map.pages.length} páginas, ${internal.size} links internos, ${external.size} externos, ${map.forms.length} formulários`);
  await browser.close();
}

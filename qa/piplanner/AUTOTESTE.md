# Resumo da execução de QA — http://127.0.0.1:4173

Execução: 2026-10-17T01:57:00.356Z · Duração: 28s

Crawler: 4 páginas · 4 links internos · 0 externos · 1 formulários

| Categoria | ✅ Passou | ❌ Falhou | ⏭️ Pulado | ⚠️ Avisos |
|---|---|---|---|---|
| Caixa branca | 23 | 0 | 13 | 36 |
| Caixa preta | 21 | 4 | 5 | 0 |
| Automatizados (E2E) | 12 | 0 | 0 | 0 |
| Usabilidade | 22 | 4 | 7 | 3 |
| Performance | 6 | 0 | 3 | 0 |

## ❌ Falhas

- **[Caixa preta] todas as páginas descobertas respondem e têm conteúdo** (desktop-chromium): Error: expect(received).toEqual(expected) // deep equality + Received  + 3 + Array [ +   "404 http://127.0.0.1:4173/pagina-quebrada 404", + ]
- **[Caixa preta] links internos sem 4xx/5xx** (desktop-chromium): Error: expect(received).toEqual(expected) // deep equality + Received  + 3 + Array [ +   "404 http://127.0.0.1:4173/pagina-quebrada", + ]
- **[Caixa preta] todas as páginas descobertas respondem e têm conteúdo** (mobile-android): Error: expect(received).toEqual(expected) // deep equality + Received  + 3 + Array [ +   "404 http://127.0.0.1:4173/pagina-quebrada 404", + ]
- **[Caixa preta] todas as páginas descobertas respondem e têm conteúdo** (mobile-ios): Error: expect(received).toEqual(expected) // deep equality + Received  + 3 + Array [ +   "404 http://127.0.0.1:4173/pagina-quebrada 404", + ]
- **[Usabilidade] axe: /** (desktop-chromium): Error: Violações críticas/graves de acessibilidade + Received  + 9 + Array [ +   Object { +     "help": "Images must have alternative text", +     "helpUrl": "https://dequeuniversity.com/rules/axe/4.10/image-alt?application=playwright",
- **[Usabilidade] axe: /** (mobile-android): Error: Violações críticas/graves de acessibilidade + Received  + 9 + Array [ +   Object { +     "help": "Images must have alternative text", +     "helpUrl": "https://dequeuniversity.com/rules/axe/4.10/image-alt?application=playwright",
- **[Usabilidade] axe: /** (mobile-ios): Error: Violações críticas/graves de acessibilidade + Received  + 9 + Array [ +   Object { +     "help": "Images must have alternative text", +     "helpUrl": "https://dequeuniversity.com/rules/axe/4.10/image-alt?application=playwright",
- **[Usabilidade] imagens com texto alternativo** (desktop-chromium): Error: Imagens sem atributo alt + Received  + 3 + Array [ +   "http://127.0.0.1:4173/ → data:image/gif;base64,R0lGODlhAQABAAAAACw=", + ]

## ⚠️ Avisos (não bloqueantes)

- [Usabilidade] Sem link "pular para o conteúdo" no primeiro Tab _(desktop-chromium)_
- [Usabilidade] 1 elemento(s) de texto com fonte < 12px _(mobile-android, mobile-ios)_
- [Caixa branca] link canonical ausente (SEO) _(desktop-chromium, mobile-android, mobile-ios)_
- [Caixa branca] Open Graph ausente (compartilhamento em redes sociais) _(desktop-chromium, mobile-android, mobile-ios)_
- [Caixa branca] favicon ausente _(desktop-chromium, mobile-android, mobile-ios)_
- [Caixa branca] meta description ausente (SEO) _(desktop-chromium, mobile-android, mobile-ios)_
- [Caixa branca] Header ausente: Content-Security-Policy _(desktop-chromium)_
- [Caixa branca] Header ausente: Proteção contra clickjacking (X-Frame-Options ou CSP frame-ancestors) _(desktop-chromium)_
- [Caixa branca] Header ausente: Referrer-Policy _(desktop-chromium)_

## ⏱️ Performance (mediana)

| Página | Dispositivo | TTFB ms | FCP ms | LCP ms | CLS | TBT ms | Load ms | Req. | KB |
|---|---|---|---|---|---|---|---|---|---|
| / | desktop-chromium | 10 | 48 | 48 | 0.000 | 0 | 23 | 1 | 2 |
| /contato | desktop-chromium | 2 | 36 | 36 | 0.000 | 0 | 14 | 1 | 1 |
| /sobre | desktop-chromium | 5 | 52 | 52 | 0.000 | 0 | 24 | 1 | 1 |
| / | mobile-android | 5 | 240 | 240 | 0.000 | 0 | 230 | 1 | 2 |
| /contato | mobile-android | 3 | 232 | 232 | 0.000 | 0 | 222 | 1 | 1 |
| /sobre | mobile-android | 4 | 200 | 200 | 0.000 | 0 | 197 | 1 | 1 |

## Detalhe por teste

| | Categoria | Teste | Dispositivo |
|---|---|---|---|
| ✅ | Automatizados (E2E) | home carrega com título e conteúdo principal | desktop-chromium |
| ✅ | Automatizados (E2E) | menu principal navega para páginas válidas | desktop-chromium |
| ✅ | Automatizados (E2E) | CTAs principais estão visíveis e habilitados | desktop-chromium |
| ✅ | Automatizados (E2E) | regressão visual das páginas principais (screenshots de evidência) | desktop-chromium |
| ✅ | Automatizados (E2E) | home carrega com título e conteúdo principal | mobile-android |
| ✅ | Automatizados (E2E) | menu principal navega para páginas válidas | mobile-android |
| ✅ | Automatizados (E2E) | CTAs principais estão visíveis e habilitados | mobile-android |
| ✅ | Automatizados (E2E) | regressão visual das páginas principais (screenshots de evidência) | mobile-android |
| ✅ | Automatizados (E2E) | home carrega com título e conteúdo principal | mobile-ios |
| ✅ | Automatizados (E2E) | menu principal navega para páginas válidas | mobile-ios |
| ✅ | Automatizados (E2E) | CTAs principais estão visíveis e habilitados | mobile-ios |
| ✅ | Automatizados (E2E) | regressão visual das páginas principais (screenshots de evidência) | mobile-ios |
| ✅ | Caixa preta | inventário de formulários | desktop-chromium |
| ✅ | Caixa preta | campos obrigatórios bloqueiam envio vazio: /contato form#0 | desktop-chromium |
| ✅ | Caixa preta | partição de equivalência em e-mail: /contato form#0 | desktop-chromium |
| ✅ | Caixa preta | valores-limite (maxlength/minlength): /contato form#0 | desktop-chromium |
| ✅ | Caixa preta | entrada maliciosa não executa script: /contato form#0 | desktop-chromium |
| ✅ | Caixa preta | inventário de formulários | mobile-android |
| ✅ | Caixa preta | campos obrigatórios bloqueiam envio vazio: /contato form#0 | mobile-android |
| ✅ | Caixa preta | partição de equivalência em e-mail: /contato form#0 | mobile-android |
| ✅ | Caixa preta | valores-limite (maxlength/minlength): /contato form#0 | mobile-android |
| ✅ | Caixa preta | entrada maliciosa não executa script: /contato form#0 | mobile-android |
| ✅ | Caixa preta | inventário de formulários | mobile-ios |
| ✅ | Caixa preta | campos obrigatórios bloqueiam envio vazio: /contato form#0 | mobile-ios |
| ✅ | Caixa preta | partição de equivalência em e-mail: /contato form#0 | mobile-ios |
| ✅ | Caixa preta | valores-limite (maxlength/minlength): /contato form#0 | mobile-ios |
| ✅ | Caixa preta | entrada maliciosa não executa script: /contato form#0 | mobile-ios |
| ❌ | Caixa preta | todas as páginas descobertas respondem e têm conteúdo | desktop-chromium |
| ❌ | Caixa preta | links internos sem 4xx/5xx | desktop-chromium |
| ⏭️ | Caixa preta | links externos (opcional: CHECK_EXTERNAL=1) | desktop-chromium |
| ✅ | Caixa preta | rota inexistente é tratada (404 ou página amigável) | desktop-chromium |
| ✅ | Caixa preta | voltar/avançar do navegador preserva a navegação | desktop-chromium |
| ❌ | Caixa preta | todas as páginas descobertas respondem e têm conteúdo | mobile-android |
| ⏭️ | Caixa preta | links internos sem 4xx/5xx | mobile-android |
| ⏭️ | Caixa preta | links externos (opcional: CHECK_EXTERNAL=1) | mobile-android |
| ✅ | Caixa preta | rota inexistente é tratada (404 ou página amigável) | mobile-android |
| ✅ | Caixa preta | voltar/avançar do navegador preserva a navegação | mobile-android |
| ❌ | Caixa preta | todas as páginas descobertas respondem e têm conteúdo | mobile-ios |
| ⏭️ | Caixa preta | links internos sem 4xx/5xx | mobile-ios |
| ⏭️ | Caixa preta | links externos (opcional: CHECK_EXTERNAL=1) | mobile-ios |
| ✅ | Caixa preta | rota inexistente é tratada (404 ou página amigável) | mobile-ios |
| ✅ | Caixa preta | voltar/avançar do navegador preserva a navegação | mobile-ios |
| ✅ | Performance | métricas: / | desktop-chromium |
| ✅ | Performance | métricas: /contato | desktop-chromium |
| ✅ | Performance | métricas: /sobre | desktop-chromium |
| ✅ | Performance | métricas: / | mobile-android |
| ✅ | Performance | métricas: /contato | mobile-android |
| ✅ | Performance | métricas: /sobre | mobile-android |
| ⏭️ | Performance | métricas: / | mobile-ios |
| ⏭️ | Performance | métricas: /contato | mobile-ios |
| ⏭️ | Performance | métricas: /sobre | mobile-ios |
| ❌ | Usabilidade | axe: / | desktop-chromium |
| ✅ | Usabilidade | axe: /contato | desktop-chromium |
| ✅ | Usabilidade | axe: /sobre | desktop-chromium |
| ❌ | Usabilidade | axe: / | mobile-android |
| ✅ | Usabilidade | axe: /contato | mobile-android |
| ✅ | Usabilidade | axe: /sobre | mobile-android |
| ❌ | Usabilidade | axe: / | mobile-ios |
| ✅ | Usabilidade | axe: /contato | mobile-ios |
| ✅ | Usabilidade | axe: /sobre | mobile-ios |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: / | desktop-chromium |
| ⏭️ | Usabilidade | alvos de toque e legibilidade: / | desktop-chromium |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /contato | desktop-chromium |
| ⏭️ | Usabilidade | alvos de toque e legibilidade: /contato | desktop-chromium |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /sobre | desktop-chromium |
| ⏭️ | Usabilidade | alvos de toque e legibilidade: /sobre | desktop-chromium |
| ✅ | Usabilidade | navegação por teclado com foco visível | desktop-chromium |
| ❌ | Usabilidade | imagens com texto alternativo | desktop-chromium |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: / | mobile-android |
| ✅ | Usabilidade | alvos de toque e legibilidade: / | mobile-android |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /contato | mobile-android |
| ✅ | Usabilidade | alvos de toque e legibilidade: /contato | mobile-android |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /sobre | mobile-android |
| ✅ | Usabilidade | alvos de toque e legibilidade: /sobre | mobile-android |
| ⏭️ | Usabilidade | navegação por teclado com foco visível | mobile-android |
| ⏭️ | Usabilidade | imagens com texto alternativo | mobile-android |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: / | mobile-ios |
| ✅ | Usabilidade | alvos de toque e legibilidade: / | mobile-ios |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /contato | mobile-ios |
| ✅ | Usabilidade | alvos de toque e legibilidade: /contato | mobile-ios |
| ✅ | Usabilidade | layout responsivo sem rolagem horizontal: /sobre | mobile-ios |
| ✅ | Usabilidade | alvos de toque e legibilidade: /sobre | mobile-ios |
| ⏭️ | Usabilidade | navegação por teclado com foco visível | mobile-ios |
| ⏭️ | Usabilidade | imagens com texto alternativo | mobile-ios |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: / | desktop-chromium |
| ✅ | Caixa branca | estrutura HTML semântica: / | desktop-chromium |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /contato | desktop-chromium |
| ✅ | Caixa branca | estrutura HTML semântica: /contato | desktop-chromium |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /sobre | desktop-chromium |
| ✅ | Caixa branca | estrutura HTML semântica: /sobre | desktop-chromium |
| ✅ | Caixa branca | cobertura de JS/CSS (código não utilizado na home) | desktop-chromium |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: / | mobile-android |
| ✅ | Caixa branca | estrutura HTML semântica: / | mobile-android |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /contato | mobile-android |
| ✅ | Caixa branca | estrutura HTML semântica: /contato | mobile-android |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /sobre | mobile-android |
| ✅ | Caixa branca | estrutura HTML semântica: /sobre | mobile-android |
| ⏭️ | Caixa branca | cobertura de JS/CSS (código não utilizado na home) | mobile-android |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: / | mobile-ios |
| ✅ | Caixa branca | estrutura HTML semântica: / | mobile-ios |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /contato | mobile-ios |
| ✅ | Caixa branca | estrutura HTML semântica: /contato | mobile-ios |
| ✅ | Caixa branca | sem exceções JS nem recursos quebrados: /sobre | mobile-ios |
| ✅ | Caixa branca | estrutura HTML semântica: /sobre | mobile-ios |
| ⏭️ | Caixa branca | cobertura de JS/CSS (código não utilizado na home) | mobile-ios |
| ✅ | Caixa branca | headers de segurança HTTP na home | desktop-chromium |
| ✅ | Caixa branca | cookies com flags Secure / HttpOnly / SameSite | desktop-chromium |
| ⏭️ | Caixa branca | sem conteúdo misto (HTTP dentro de HTTPS) | desktop-chromium |
| ✅ | Caixa branca | segredos e source maps no código JS entregue | desktop-chromium |
| ✅ | Caixa branca | arquivos sensíveis não expostos | desktop-chromium |
| ⏭️ | Caixa branca | headers de segurança HTTP na home | mobile-android |
| ⏭️ | Caixa branca | cookies com flags Secure / HttpOnly / SameSite | mobile-android |
| ⏭️ | Caixa branca | sem conteúdo misto (HTTP dentro de HTTPS) | mobile-android |
| ⏭️ | Caixa branca | segredos e source maps no código JS entregue | mobile-android |
| ⏭️ | Caixa branca | arquivos sensíveis não expostos | mobile-android |
| ⏭️ | Caixa branca | headers de segurança HTTP na home | mobile-ios |
| ⏭️ | Caixa branca | cookies com flags Secure / HttpOnly / SameSite | mobile-ios |
| ⏭️ | Caixa branca | sem conteúdo misto (HTTP dentro de HTTPS) | mobile-ios |
| ⏭️ | Caixa branca | segredos e source maps no código JS entregue | mobile-ios |
| ⏭️ | Caixa branca | arquivos sensíveis não expostos | mobile-ios |

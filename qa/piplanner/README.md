# Suíte de QA — piplanner.io

Testes de **caixa branca**, **caixa preta**, **automatizados (E2E)**, **usabilidade** e **performance** para [https://piplanner.io](https://piplanner.io), em **desktop**, **Android (Pixel 7)** e **iPhone 14** (emulado no Chromium).

Antes dos testes, um crawler percorre o site (até `MAX_PAGES` páginas) e grava as páginas, links e formulários encontrados em `reports/site-map.json`. Os testes usam esse mapa, então a suíte cobre automaticamente as funcionalidades que existirem no site, sem roteiro fixo por página.

## Como executar

```bash
cd qa/piplanner
npm ci
./scripts/run-all.sh          # suíte completa (~10–15 min no site real)
./scripts/run-all.sh leve     # versão leve: desktop, 5 páginas, 1 medição (~2–3 min)
npx playwright show-report reports/html   # relatório HTML com evidências
```

Resultado consolidado: `reports/RESUMO.md`.

Por categoria: `npm run test:white-box`, `test:black-box`, `test:automated`, `test:usability` e `test:performance`.

### Variáveis de ambiente

| Variável | Padrão | Uso |
|---|---|---|
| `BASE_URL` | `https://piplanner.io` | Alvo; use homologação quando houver |
| `MAX_PAGES` | 20 | Páginas descobertas pelo crawler |
| `PERF_PAGES` / `PERF_RUNS` | 5 / 3 | Páginas e repetições medidas em performance |
| `ALLOW_SUBMIT=1` | desligado | Permite **envio real** de formulários (pode criar leads/cadastros) |
| `CHECK_EXTERNAL=1` | desligado | Verifica também os links externos |

### Autoteste da suíte (sem acessar o site)

```bash
npm run serve:fixture &   # servidor local com defeitos propositais
npm run test:selftest && npm run report
```

As páginas em `fixtures/` têm um link quebrado, uma imagem sem `alt` e texto pequeno de propósito. As falhas esperadas no autoteste são exatamente essas.

## Plano de testes

| Categoria | Arquivo | O que verifica | Critério |
|---|---|---|---|
| **Caixa branca** | `tests/white-box/code-quality.spec.ts` | Exceções JS, erros de console, recursos 4xx/5xx; HTML semântico (`lang`, `title`, `viewport`, IDs duplicados, `h1`); SEO (description, canonical, Open Graph, favicon); cobertura de JS/CSS | Exceção JS reprova; demais itens são avisos |
| | `tests/white-box/security.spec.ts` | Headers (HSTS, CSP, nosniff, clickjacking, Referrer-Policy); cookies (Secure/HttpOnly/SameSite); conteúdo misto; segredos no bundle; source maps; arquivos sensíveis (`.git`, `.env`) | Segredo ou arquivo exposto reprova; header ausente é aviso |
| **Caixa preta** | `tests/black-box/navigation.spec.ts` | Páginas respondem com conteúdo; links internos sem 4xx/5xx; tratamento de 404; voltar/avançar | Link ou página quebrada reprova |
| | `tests/black-box/forms.spec.ts` | Campos obrigatórios; **partição de equivalência** em e-mail; **valor-limite** em maxlength/minlength; entrada maliciosa (XSS) sem execução | Validação ausente ou script executado reprova |
| **Automatizados** | `tests/automated/smoke.spec.ts` | Home carrega; menu (inclusive hambúrguer no mobile) navega; CTAs visíveis/habilitados; screenshots de evidência | Pronto para rodar em CI a cada deploy |
| **Usabilidade** | `tests/usability/accessibility.spec.ts` | axe-core, WCAG 2.1 A/AA | Violação *critical/serious* reprova |
| | `tests/usability/ux.spec.ts` | Rolagem horizontal; alvos de toque (24px WCAG 2.2, 44px recomendado); fonte < 12px; zoom do iOS em inputs < 16px; foco visível por teclado; `alt` em imagens | Overflow, alvo < 24px e imagem sem `alt` reprovam |
| **Performance** | `tests/performance/web-vitals.spec.ts` | TTFB, FCP, LCP, CLS, TBT, load, nº de requisições e peso; mediana de N execuções sem cache; Android com CPU 4x + 4G simulado | Acima do limite "ruim" do Google reprova; "precisa melhorar" é aviso |

Limites de Core Web Vitals (bom / ruim): LCP 2,5 s / 4 s · FCP 1,8 s / 3 s · TTFB 0,8 s / 1,8 s · CLS 0,1 / 0,25 · TBT 200 ms / 600 ms.

## Limitações

- **iPhone emulado**: viewport, toque e user-agent do iPhone 14 no Chromium (WebKit não está instalado no ambiente). Para Safari real, use `npx playwright install webkit` e troque `browserName` no projeto `mobile-ios`.
- **Performance de laboratório**: medida a partir do servidor que executa os testes. Serve para comparar versões e detectar regressões, não substitui dados de campo (CrUX/RUM).
- **Áreas logadas** não são cobertas sem credenciais de teste.
- **Carga**: a suíte completa gera ~5–15 mil requisições. Execute com autorização do responsável pelo site, de preferência em homologação.

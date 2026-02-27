# Relatório de Compatibilidade - Assinatura `2026.html`

Data: 2026-02-27

## Escopo solicitado
- Outlook Mobile (Android e iOS)
- Gmail em Windows e Mac

## Metodologia executada
1. **Validação estrutural do HTML** (parser nativo Python).
2. **Validação dos links em áreas clicáveis (`<map><area>`)** para os ícones da barra laranja.
3. **Evidência visual por viewport** com Playwright:
   - Android (Pixel 7)
   - iOS (iPhone 14)
   - Desktop Windows (viewport 1366x768 + user-agent Windows)
   - Desktop Mac (viewport 1440x900 + user-agent Mac)

## Resultado dos testes executados

### 1) Estrutura HTML
- **Status:** OK
- Evidência de comando: `HTML parse ok`.

### 2) Links nos ícones da barra laranja
- **Status:** OK (mapeamento presente no HTML)
- Áreas encontradas no `<map>`:
  - Site Adapt Works → `https://adapt.works/`
  - WhatsApp Adapt Works → `https://wa.me/5511913551131`
  - Instagram Adapt Works → `https://www.instagram.com/adaptworks/`
  - LinkedIn Adapt Works → `https://www.linkedin.com/company/adaptworks`
  - Facebook Adapt Works → `https://www.facebook.com/adaptworks/`
  - E-mail → `mailto:fpechibella@adaptworks.com.br`

### 3) Evidências visuais geradas
- Android mobile: `browser:/tmp/codex_browser_invocations/579e075efcf91dd6/artifacts/artifacts/evidence-android-mobile.png`
- iOS mobile: `browser:/tmp/codex_browser_invocations/579e075efcf91dd6/artifacts/artifacts/evidence-ios-mobile.png`
- Gmail web (Windows): `browser:/tmp/codex_browser_invocations/579e075efcf91dd6/artifacts/artifacts/evidence-gmail-web-windows.png`
- Gmail web (Mac): `browser:/tmp/codex_browser_invocations/579e075efcf91dd6/artifacts/artifacts/evidence-gmail-web-mac.png`

## Limitações importantes
- Este ambiente **não possui Outlook Mobile/Gmail app reais** para validação nativa de renderização com o motor de cada aplicativo.
- Portanto, os resultados mobile são de **simulação de viewport/browser** (boa evidência visual/layout), mas **não substituem** testes reais em dispositivos/apps.

## Recomendação para fechamento 100%
- Validar em plataforma dedicada (Litmus ou Email on Acid) com capturas de:
  - Outlook Android
  - Outlook iOS
  - Gmail Android
  - Gmail iOS
  - Gmail web (Chrome/Edge no Windows, Chrome/Safari no Mac)


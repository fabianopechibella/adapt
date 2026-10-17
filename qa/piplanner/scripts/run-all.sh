#!/usr/bin/env bash
# Executa a suíte completa e gera o resumo. Uso:
#   ./scripts/run-all.sh                    -> https://piplanner.io (suíte completa)
#   ./scripts/run-all.sh leve               -> versão leve: só desktop, 5 páginas, 1 medição
#   BASE_URL=https://staging.piplanner.io ./scripts/run-all.sh
set -uo pipefail
cd "$(dirname "$0")/.."
rm -rf reports && mkdir -p reports
if [[ "${1:-}" == "leve" ]]; then
  MAX_PAGES=5 PERF_PAGES=2 PERF_RUNS=1 npx playwright test --project=desktop-chromium
else
  npx playwright test
fi
status=$?
node scripts/summarize.mjs
echo "Relatório HTML: npx playwright show-report reports/html"
exit $status

// Gera reports/RESUMO.md a partir de reports/results.json e reports/perf/*.json.
import fs from 'node:fs';
import path from 'node:path';

const dir = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'reports');
const results = JSON.parse(fs.readFileSync(path.join(dir, 'results.json'), 'utf8'));
const map = JSON.parse(fs.readFileSync(path.join(dir, 'site-map.json'), 'utf8'));
const CATEGORY = { 'white-box': 'Caixa branca', 'black-box': 'Caixa preta', automated: 'Automatizados (E2E)', usability: 'Usabilidade', performance: 'Performance', authenticated: 'Área logada' };

const rows = [];
const walk = (suite, file) => {
  for (const s of suite.suites || []) walk(s, s.file || file);
  for (const spec of suite.specs || []) for (const t of spec.tests) {
    const r = t.results.at(-1) || {};
    const status = t.status === 'skipped' ? 'skipped' : r.status === 'passed' ? 'passed' : 'failed';
    rows.push({
      category: CATEGORY[(spec.file || file).split('/')[0]] || 'Outros', title: spec.title, project: t.projectName, status,
      warnings: t.annotations.filter((a) => a.type === 'warning').map((a) => a.description),
      error: (r.errors || []).map((e) => (e.message || '').replace(/\u001b\[[0-9;]*m/g, '').split('\n').filter((l) => /^\s*(Error|\+ |Expected|Received)/.test(l)).slice(0, 6).map((l) => l.trim()).join(' ')).join(' | '),
    });
  }
};
results.suites.forEach((s) => walk(s, s.file));

const out = [];
const icon = { passed: '✅', failed: '❌', skipped: '⏭️' };
out.push(`# Resumo da execução de QA — ${map.baseURL}`, '', `Execução: ${new Date().toISOString()} · Duração: ${(results.stats.duration / 1000).toFixed(0)}s`, '');
out.push(`Crawler: ${map.pages.length} páginas · ${map.internalLinks.length} links internos · ${map.externalLinks.length} externos · ${map.forms.length} formulários`, '');
out.push('| Categoria | ✅ Passou | ❌ Falhou | ⏭️ Pulado | ⚠️ Avisos |', '|---|---|---|---|---|');
for (const cat of Object.values(CATEGORY)) {
  const r = rows.filter((x) => x.category === cat);
  if (!r.length) continue;
  const c = (s) => r.filter((x) => x.status === s).length;
  out.push(`| ${cat} | ${c('passed')} | ${c('failed')} | ${c('skipped')} | ${r.reduce((s, x) => s + x.warnings.length, 0)} |`);
}
const failed = rows.filter((r) => r.status === 'failed');
if (failed.length) {
  out.push('', '## ❌ Falhas', '');
  for (const f of failed) out.push(`- **[${f.category}] ${f.title}** (${f.project}): ${f.error.slice(0, 400)}`);
}
const warnings = new Map();
for (const r of rows) for (const w of r.warnings) warnings.set(`[${r.category}] ${w}`, [...(warnings.get(`[${r.category}] ${w}`) || []), r.project]);
if (warnings.size) {
  out.push('', '## ⚠️ Avisos (não bloqueantes)', '');
  for (const [w, projects] of warnings) out.push(`- ${w} _(${[...new Set(projects)].join(', ')})_`);
}
const perfDir = path.join(dir, 'perf');
if (fs.existsSync(perfDir)) {
  out.push('', '## ⏱️ Performance (mediana)', '', '| Página | Dispositivo | TTFB ms | FCP ms | LCP ms | CLS | TBT ms | Load ms | Req. | KB |', '|---|---|---|---|---|---|---|---|---|---|');
  for (const f of fs.readdirSync(perfDir).sort()) {
    const { url, device, median: m } = JSON.parse(fs.readFileSync(path.join(perfDir, f), 'utf8'));
    out.push(`| ${new URL(url).pathname} | ${device} | ${m.ttfb.toFixed(0)} | ${m.fcp.toFixed(0)} | ${m.lcp.toFixed(0)} | ${m.cls.toFixed(3)} | ${m.tbt.toFixed(0)} | ${m.load.toFixed(0)} | ${m.requests} | ${m.transferKB.toFixed(0)} |`);
  }
}
const appDir = path.join(dir, 'app');
if (fs.existsSync(appDir)) {
  out.push('', '## 🔐 Área logada — telas', '', '| Tela | Dispositivo | Pronta em (ms) | Chamadas API | API ≥ 400 | Acessibilidade (graves) | Exceções JS |', '|---|---|---|---|---|---|---|');
  for (const f of fs.readdirSync(appDir).sort()) {
    const r = JSON.parse(fs.readFileSync(path.join(appDir, f), 'utf8'));
    const bad = r.api.filter((a) => a.status >= 400).map((a) => `${a.status} ${a.url}`).join('<br>') || '—';
    out.push(`| ${r.label} (${new URL(r.url).pathname}) | ${r.device} | ${r.readyMs}${r.stuck ? ' ⚠️ travou' : ''} | ${r.api.length} | ${bad} | ${r.axe.join(', ') || '—'} | ${r.exceptions.length} |`);
  }
}
out.push('', '## Detalhe por teste', '', '| | Categoria | Teste | Dispositivo |', '|---|---|---|---|');
for (const r of rows) out.push(`| ${icon[r.status]} | ${r.category} | ${r.title} | ${r.project} |`);
fs.writeFileSync(path.join(dir, 'RESUMO.md'), out.join('\n') + '\n');
console.log(`Resumo gravado em ${path.join(dir, 'RESUMO.md')}`);

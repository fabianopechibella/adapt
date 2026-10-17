# Resumo — Bateria Selenium piplanner.io (17/10/2026)

61 testes: 55 aprovados, 6 reprovados. As reprovações correspondem a achados confirmados (a de carga só reprova por limite de login quando a suíte roda em sequência; isolada, passa).

## Por categoria

| Categoria | Aprovados | Reprovados | Observação |
|---|---|---|---|
| UI login (Selenium) | 5 | 0 | Login, senha errada, senha fora da política, rota protegida |
| UI navegação 18 telas (Selenium) | 17 | 1 | Dashboard quebra ao interpretar HTML como JSON |
| API | 25 | 2 | Rotas 404 e token malformado gerando 500 |
| Links e integrações | 5 | 0 | Recursos, vídeo, links externos e 404 OK |
| Segurança (leitura) | 3 | 2 | Headers ausentes e X-Powered-By |
| Carga/estresse | 0 | 1* | *artefato de limite de login; execução isolada passou |

## Achados

| Severidade | Achado | Evidência |
|---|---|---|
| Alta | Dashboard quebra: chama /api/strategic-objectives, recebe 404 (HTML) e tenta ler como JSON → SyntaxError no console | test_02, console do navegador |
| Média | Token malformado (Bearer abc:def) gera HTTP 500 em vez de 401 | test_03 |
| Média | Rotas chamadas pelo frontend retornam 404: /api/rte-agent/health, /api/cost-centers | test_03 |
| Média | Headers de segurança ausentes: HSTS, CSP, X-Content-Type-Options, X-Frame-Options, Referrer-Policy | test_05 |
| Média | Servidor expõe tecnologia: X-Powered-By: Express | test_05 |

## Pontos fortes confirmados

- Autorização validada no servidor: token ausente → 401; organização trocada → 403; usuário inexistente → 401.
- Endpoints protegidos recusam acesso sem token (11 endpoints testados).
- Sem enumeração de usuários; limite de login ativo (20/15min por IP).
- Nenhum arquivo sensível (.env, .git) acessível.
- Backend sólido sob carga: 5→30 requisições simultâneas (240 no total), 0 erros 5xx, latência média ~0,5 s, sem acionar a parada de segurança.
- As 18 telas internas carregam com sessão e conteúdo.

## Observações de autenticação

A API autentica por cabeçalho Authorization: Bearer <user_id>:<organization_id>, valores obtidos no login e guardados no navegador. O servidor valida corretamente a organização e a existência do usuário. Recomenda-se, mesmo assim, avaliar a migração para tokens assinados (ex.: JWT com expiração) em um próximo ciclo, por serem o padrão de mercado e reduzirem a superfície de risco.

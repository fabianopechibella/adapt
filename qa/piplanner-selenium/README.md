# Bateria Selenium — piplanner.io

Testes no padrão Selenium WebDriver (Python + pytest, com Page Object Model), somados a testes de API, links/integrações, segurança defensiva e carga controlada. Cada teste gera evidência; o relatório sai em HTML.

## Como executar

```bash
cd qa/piplanner-selenium
pip install -r requirements.txt
# ChromeDriver compatível com o Chromium do ambiente:
export CHROMEDRIVER=/caminho/para/chromedriver
export CHROME_BIN=/caminho/para/chrome
export QA_USER='usuario@empresa.com' QA_PASS='***'

pytest -v --html=relatorios/completo.html --self-contained-html
```

Credenciais vêm só de variáveis de ambiente; nunca ficam no código. O servidor limita o login a 20 tentativas por 15 min por IP: evite mais de 3 execuções completas por janela.

## Cobertura

| Arquivo | Tipo | O que cobre |
|---|---|---|
| `tests/test_01_login_ui.py` | UI (Selenium) | Login válido, senha errada, senha fora da política, rota protegida sem sessão |
| `tests/test_02_navegacao_ui.py` | UI (Selenium) | As 18 telas da área logada carregam sem erro de JS, sessão e conteúdo |
| `tests/test_03_api.py` | API | Contrato de login, autenticação, autorização, rotas 404, robustez a token malformado |
| `tests/test_04_links_integracao.py` | Links/integração | Recursos estáticos, vídeo da home, links externos, rota inexistente |
| `tests/test_05_seguranca.py` | Segurança (leitura) | Headers, exposição de tecnologia, limite de login, enumeração de usuários, arquivos sensíveis |
| `tests/test_06_carga.py` | Carga/estresse | Carga progressiva (5→30 simultâneos) com parada de segurança automática |

## Salvaguardas

- **Somente leitura**: nenhum teste cria, altera ou exclui dados.
- **Carga com parada automática**: interrompe se erro 5xx passar de 20% ou latência média passar de 5 s, para não impactar produção.
- **Evidências**: screenshots em `evidencias/` (dados pessoais ocultados); relatórios HTML em `relatorios/`.

## Limitações

- Navegador: Chromium headless (sem Safari real nem aparelho físico).
- Carga medida de um datacenter; serve para comparar e detectar regressão, não reproduz a experiência do usuário final.
- Funções de cadastro/edição não são exercitadas (modo leitura); exigiriam ambiente de homologação descartável.

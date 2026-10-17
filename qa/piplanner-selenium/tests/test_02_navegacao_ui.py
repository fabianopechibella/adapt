"""Testes de UI (Selenium) — navegação pelas 18 telas da área logada, modo leitura."""
import time
import pytest
from selenium.webdriver.common.by import By
from conftest import BASE_URL, QA_USER, QA_PASS, shot
from pages.login_page import LoginPage

pytestmark = pytest.mark.skipif(not (QA_USER and QA_PASS), reason="QA_USER/QA_PASS necessários")

TELAS = [
    ("Dashboard", "/Dashboard"), ("Ciclos de Planejamento", "/PICycles"), ("OKRs", "/OKRs"),
    ("Fluxos de Valor", "/ValueStreams"), ("Visao de Recursos", "/ResourceManagement"),
    ("Gestao de Talentos", "/TalentManagement"), ("Catalogo de Skills", "/SkillsCatalog"),
    ("Carga de Alocacao", "/AllocationWorkload"), ("Estrutura Organizacional", "/OrganizationalStructure"),
    ("Topologia de Entrega", "/Teams"), ("Papeis", "/Roles"), ("Empresas", "/Companies"),
    ("Contratos", "/Contracts"), ("Taxonomia de Trabalho", "/WorkTaxonomy"),
    ("Gestao de Usuarios", "/UserManagement"), ("Papeis e Permissoes", "/RolesPermissions"),
    ("Configuracoes do Sistema", "/SystemSettings"), ("Auditoria e Logs", "/AuditLogs"),
]


@pytest.fixture(scope="module")
def logged_driver():
    from conftest import _make_driver
    d = _make_driver()
    LoginPage(d, BASE_URL).login(QA_USER, QA_PASS)
    from selenium.webdriver.support.ui import WebDriverWait
    WebDriverWait(d, 30).until(lambda x: "/login" not in x.current_url)
    yield d
    d.quit()


@pytest.mark.parametrize("nome,rota", TELAS)
def test_tela_carrega_sem_erro(logged_driver, nome, rota):
    d = logged_driver
    t0 = time.time()
    d.get(BASE_URL + rota)
    WebDriverWait = __import__("selenium.webdriver.support.ui", fromlist=["WebDriverWait"]).WebDriverWait
    try:
        WebDriverWait(d, 20).until(lambda x: "carregando" not in x.find_element(By.TAG_NAME, "body").text.lower()[:200])
    except Exception:
        pass
    ms = int((time.time() - t0) * 1000)
    slug = rota.strip("/").lower()
    shot(d, f"tela-{slug}")
    body = d.find_element(By.TAG_NAME, "body").text
    # Erros de JavaScript no console
    erros = [l["message"] for l in d.get_log("browser") if l["level"] == "SEVERE" and "/api/" not in l["message"]]
    assert "/login" not in d.current_url, f"{nome}: sessão perdida"
    assert len(body.strip()) > 30, f"{nome}: tela vazia"
    assert not erros, f"{nome}: erro JS no console: {erros[:2]}"

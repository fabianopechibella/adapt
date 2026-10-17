"""Testes de API — autenticação, autorização e endpoints do backend.

A aplicação autentica por cabeçalho Authorization: Bearer <user_id>:<org_id>,
obtido no login. Estes testes são de leitura (GET) e validam contratos e proteção.
"""
import os
import json
import pytest
import httpx

BASE_URL = os.environ.get("BASE_URL", "https://piplanner.io").rstrip("/")
QA_USER = os.environ.get("QA_USER", "")
QA_PASS = os.environ.get("QA_PASS", "")
PROXY = os.environ.get("HTTPS_PROXY", "") or None

pytestmark = pytest.mark.skipif(not (QA_USER and QA_PASS), reason="QA_USER/QA_PASS necessários")


@pytest.fixture(scope="module")
def session():
    with httpx.Client(base_url=BASE_URL, proxy=PROXY, timeout=30, verify=False) as c:
        yield c


@pytest.fixture(scope="module")
def auth(session):
    r = session.post("/api/auth/login", json={"email": QA_USER, "password": QA_PASS})
    assert r.status_code == 200, f"Login falhou: {r.status_code}"
    u = r.json()["user"]
    return {"Authorization": f"Bearer {u['id']}:{u['organization_id']}"}


ENDPOINTS_GET = [
    "/api/auth/me", "/api/pi-plannings", "/api/risks", "/api/notifications",
    "/api/strategic-objectives", "/api/teams", "/api/roles", "/api/companies",
    "/api/contracts", "/api/users", "/api/organizational-units",
]


def test_login_retorna_contrato_esperado(session):
    r = session.post("/api/auth/login", json={"email": QA_USER, "password": QA_PASS})
    assert r.status_code == 200
    d = r.json()
    assert "user" in d and "id" in d["user"] and "organization_id" in d["user"]
    assert "permissions" in d


def test_login_sem_senha_rejeitado(session):
    r = session.post("/api/auth/login", json={"email": QA_USER})
    assert r.status_code >= 400


def test_login_credencial_invalida(session):
    r = session.post("/api/auth/login", json={"email": QA_USER, "password": "Errada999"})
    assert r.status_code in (400, 401), f"Esperado 400/401, veio {r.status_code}"


@pytest.mark.parametrize("ep", ENDPOINTS_GET)
def test_endpoint_sem_token_recusa(session, ep):
    """Endpoint protegido não deve devolver dados sem Authorization."""
    r = session.get(ep, headers={"Accept": "application/json"})
    if r.status_code == 200 and not r.text.lstrip().startswith("<"):
        pytest.fail(f"{ep} devolveu dados sem token (200)")
    assert r.status_code in (401, 403, 404) or r.text.lstrip().startswith("<")


@pytest.mark.parametrize("ep", ENDPOINTS_GET)
def test_endpoint_com_token_responde(session, auth, ep):
    r = session.get(ep, headers={**auth, "Accept": "application/json"})
    assert r.status_code < 500, f"{ep}: erro de servidor {r.status_code}"
    assert r.status_code != 403, f"{ep}: token válido recebeu 403"


def test_rotas_404_conhecidas(session, auth):
    """Documenta rotas que o frontend chama mas o backend não implementa."""
    faltando = []
    for ep in ["/api/rte-agent/health", "/api/cost-centers"]:
        r = session.get(ep, headers={**auth, "Accept": "application/json"})
        if r.status_code == 404:
            faltando.append(ep)
    assert not faltando, f"Rotas chamadas pelo frontend que retornam 404: {faltando}"


def test_token_malformado_nao_gera_erro_500(session):
    """Robustez: token mal formado deve dar 401, não 500 (erro interno)."""
    r = session.get("/api/auth/me", headers={"Authorization": "Bearer abc:def", "Accept": "application/json"})
    assert r.status_code != 500, "Token malformado gera 500 (falta tratar entrada inválida)"
    assert r.status_code in (400, 401), f"Esperado 401, veio {r.status_code}"

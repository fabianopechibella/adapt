"""Verificação defensiva de segurança da camada web (somente leitura)."""
import os
import pytest
import httpx

BASE_URL = os.environ.get("BASE_URL", "https://piplanner.io").rstrip("/")
QA_USER = os.environ.get("QA_USER", "")
QA_PASS = os.environ.get("QA_PASS", "")
PROXY = os.environ.get("HTTPS_PROXY", "") or None


@pytest.fixture(scope="module")
def client():
    with httpx.Client(timeout=30, verify=False, proxy=PROXY) as c:
        yield c


def test_headers_de_seguranca(client):
    h = client.get(BASE_URL + "/").headers
    ausentes = [name for name, ok in [
        ("Strict-Transport-Security", "strict-transport-security" in h),
        ("Content-Security-Policy", "content-security-policy" in h),
        ("X-Content-Type-Options", "nosniff" in h.get("x-content-type-options", "")),
        ("X-Frame-Options/frame-ancestors", "x-frame-options" in h or "frame-ancestors" in h.get("content-security-policy", "")),
        ("Referrer-Policy", "referrer-policy" in h),
    ] if not ok]
    assert not ausentes, f"Headers de segurança ausentes: {ausentes}"


def test_servidor_nao_expoe_tecnologia(client):
    h = client.get(BASE_URL + "/").headers
    exposto = [k for k in ("x-powered-by",) if k in h]
    assert not exposto, f"Headers que expõem tecnologia: {[(k, h[k]) for k in exposto]}"


def test_limite_de_tentativas_de_login(client):
    r = client.post(BASE_URL + "/api/auth/login", json={"email": "x@x.com", "password": "y"})
    assert "ratelimit-limit" in r.headers or "retry-after" in r.headers, \
        "Login sem indício de limite de tentativas (risco de força bruta)"


@pytest.mark.skipif(not (QA_USER and QA_PASS), reason="credenciais necessárias")
def test_sem_enumeracao_de_usuarios(client):
    kw = {"password": "SenhaErrada123"}
    r1 = client.post(BASE_URL + "/api/auth/login", json={"email": QA_USER, **kw})
    r2 = client.post(BASE_URL + "/api/auth/login", json={"email": "naoexiste-qa@exemplo.com", **kw})
    assert r1.status_code == r2.status_code and r1.text == r2.text, \
        "Respostas diferentes para e-mail existente x inexistente: permite enumerar usuários"


def test_arquivos_sensiveis_nao_expostos(client):
    expostos = []
    for p in ["/.env", "/.git/HEAD", "/.git/config", "/config.json"]:
        r = client.get(BASE_URL + p)
        if r.status_code == 200 and not r.text.lstrip().startswith("<"):
            expostos.append(p)
    assert not expostos, f"Arquivos sensíveis acessíveis: {expostos}"

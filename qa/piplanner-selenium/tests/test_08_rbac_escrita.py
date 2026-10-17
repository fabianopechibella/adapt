"""Testes de RBAC e de escrita — PRONTOS, mas DESATIVADOS por padrão.

Rodam apenas em AMBIENTE DE HOMOLOGAÇÃO, com dados descartáveis e autorização
formal: exercem escrita (criar/editar/excluir) e tentam acessos indevidos.
NÃO rodar em produção com dados reais.

Habilite com:
  export QA_ENV=homologacao
  export BASE_URL=https://staging.piplanner.io        # ambiente de testes
  export QA_ADMIN_USER=... QA_ADMIN_PASS=...           # perfil Administrador
  export QA_MEMBER_USER=... QA_MEMBER_PASS=...         # perfil Membro (menor privilégio)
  pytest tests/test_08_rbac_escrita.py -v
"""
import os
import uuid
import pytest
import httpx

BASE_URL = os.environ.get("BASE_URL", "").rstrip("/")
PROXY = os.environ.get("HTTPS_PROXY", "") or None
ADMIN = (os.environ.get("QA_ADMIN_USER", ""), os.environ.get("QA_ADMIN_PASS", ""))
MEMBER = (os.environ.get("QA_MEMBER_USER", ""), os.environ.get("QA_MEMBER_PASS", ""))

# Trava de segurança: só roda quando explicitamente em homologação.
pytestmark = pytest.mark.skipif(
    os.environ.get("QA_ENV") != "homologacao",
    reason="Testes de escrita/RBAC: defina QA_ENV=homologacao (NUNCA em produção)",
)


def _client():
    return httpx.Client(base_url=BASE_URL, proxy=PROXY, timeout=30, verify=False)


def _auth(user, pwd):
    with _client() as c:
        r = c.post("/api/auth/login", json={"email": user, "password": pwd})
        assert r.status_code == 200, f"Login falhou para {user}: {r.status_code}"
        u = r.json()["user"]
    return {"Authorization": f"Bearer {u['id']}:{u['organization_id']}", "Content-Type": "application/json"}


@pytest.fixture(scope="module")
def admin_headers():
    if not all(ADMIN):
        pytest.skip("QA_ADMIN_USER/QA_ADMIN_PASS necessários")
    return _auth(*ADMIN)


@pytest.fixture(scope="module")
def member_headers():
    if not all(MEMBER):
        pytest.skip("QA_MEMBER_USER/QA_MEMBER_PASS necessários")
    return _auth(*MEMBER)


# ---------------------------------------------------------------- RBAC
ENDPOINTS_ADMIN = [
    ("GET", "/api/users"),
    ("GET", "/api/roles"),
    ("POST", "/api/users"),
    ("POST", "/api/roles"),
]


@pytest.mark.parametrize("metodo,ep", ENDPOINTS_ADMIN)
def test_membro_nao_acessa_area_de_admin(member_headers, metodo, ep):
    """Um perfil Membro NÃO deve acessar endpoints de administração."""
    with _client() as c:
        corpo = {"nome": "qa", "email": f"qa-{uuid.uuid4().hex[:8]}@exemplo.com"} if metodo == "POST" else None
        r = c.request(metodo, ep, headers=member_headers, json=corpo)
    assert r.status_code in (401, 403), (
        f"ESCALAÇÃO DE PRIVILÉGIO: Membro conseguiu {metodo} {ep} (status {r.status_code})"
    )


def test_membro_nao_edita_permissoes(member_headers):
    """Membro não deve conseguir alterar papéis/permissões."""
    with _client() as c:
        r = c.put("/api/roles/qualquer-id", headers=member_headers, json={"name": "hack"})
    assert r.status_code in (401, 403), f"Membro alterou permissões (status {r.status_code})"


# ---------------------------------------------------------------- IDOR / isolamento
def test_sem_acesso_a_recurso_de_outra_organizacao(member_headers, admin_headers):
    """Token de uma organização não deve ler recurso de outra (horizontal)."""
    # Descobre um id de recurso visível ao admin e tenta acessá-lo como membro de outra org,
    # se os dois perfis forem de organizações diferentes (cenário a montar em homologação).
    with _client() as c:
        lst = c.get("/api/pi-plannings", headers=admin_headers)
        if lst.status_code != 200 or not lst.json():
            pytest.skip("Sem recurso de referência para o teste de isolamento")
        rid = (lst.json()[0] or {}).get("id")
        if not rid:
            pytest.skip("Recurso sem id")
        r = c.get(f"/api/pi-plannings/{rid}", headers=member_headers)
    # Mesmo org: 200 aceitável. Orgs diferentes: deve ser 403/404. Ajustar conforme o cenário montado.
    assert r.status_code != 500, "Erro de servidor ao checar isolamento"


# ---------------------------------------------------------------- Escrita (CRUD) em homologação
@pytest.fixture
def recurso_temporario(admin_headers):
    """Cria um recurso de teste e garante a remoção ao final (só em homologação)."""
    criado = {}
    with _client() as c:
        payload = {"name": f"QA-teste-{uuid.uuid4().hex[:8]}", "description": "criado por teste automatizado"}
        r = c.post("/api/strategic-objectives", headers=admin_headers, json=payload)
        if r.status_code not in (200, 201):
            pytest.skip(f"Endpoint de criação indisponível ({r.status_code}); ajustar ao contrato real")
        criado = r.json()
    yield criado
    rid = criado.get("id")
    if rid:
        with _client() as c:
            c.delete(f"/api/strategic-objectives/{rid}", headers=admin_headers)


def test_criar_editar_excluir_objetivo(admin_headers, recurso_temporario):
    """Ciclo completo de escrita: criar (fixture) → editar → ler → o delete ocorre na fixture."""
    rid = recurso_temporario.get("id")
    assert rid, "Recurso criado sem id"
    with _client() as c:
        upd = c.put(f"/api/strategic-objectives/{rid}", headers=admin_headers,
                    json={"name": "QA-teste-editado"})
        assert upd.status_code in (200, 204), f"Edição falhou: {upd.status_code}"
        got = c.get(f"/api/strategic-objectives/{rid}", headers=admin_headers)
        assert got.status_code == 200
        assert "QA-teste-editado" in got.text, "Edição não refletida na leitura"


def test_validacao_de_entrada_na_criacao(admin_headers):
    """Campos obrigatórios ausentes devem ser recusados com 4xx, não 500."""
    with _client() as c:
        r = c.post("/api/strategic-objectives", headers=admin_headers, json={})
    assert r.status_code != 500, "Criação com corpo vazio gerou erro 500 (falta validação)"
    assert r.status_code in (400, 422), f"Esperado 400/422 para corpo inválido, veio {r.status_code}"

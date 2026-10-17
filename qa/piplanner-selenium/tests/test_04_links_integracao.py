"""Testes de links quebrados, recursos estáticos e integrações externas."""
import os
import re
import pytest
import httpx

BASE_URL = os.environ.get("BASE_URL", "https://piplanner.io").rstrip("/")
PROXY = os.environ.get("HTTPS_PROXY", "") or None


@pytest.fixture(scope="module")
def client():
    with httpx.Client(timeout=30, verify=False, proxy=PROXY, follow_redirects=True,
                      headers={"User-Agent": "Mozilla/5.0 QA-Bot"}) as c:
        yield c


def _coletar_links(client):
    html = client.get(BASE_URL + "/").text
    hrefs = set(re.findall(r'href="(https?://[^"]+)"', html))
    srcs = set(re.findall(r'src="(https?://[^"]+)"', html))
    return hrefs | srcs


def test_home_responde(client):
    r = client.get(BASE_URL + "/")
    assert r.status_code == 200


def test_recursos_estaticos_sem_quebra(client):
    html = client.get(BASE_URL + "/").text
    assets = set(re.findall(r'(?:src|href)="(/[^"]+\.(?:js|css|png|svg|webp|ico|woff2?))"', html))
    quebrados = []
    for a in assets:
        r = client.get(BASE_URL + a)
        if r.status_code >= 400:
            quebrados.append(f"{r.status_code} {a}")
    assert not quebrados, f"Recursos estáticos quebrados: {quebrados}"


def test_video_demonstracao_board(client):
    """O vídeo da home (board-*.webm) registrou ERR_ABORTED no teste anterior."""
    html = client.get(BASE_URL + "/").text
    vids = re.findall(r'(/assets/[^"]+\.webm)', html)
    problemas = []
    for v in set(vids):
        r = client.get(BASE_URL + v, headers={"Range": "bytes=0-1023"})
        if r.status_code >= 400:
            problemas.append(f"{r.status_code} {v}")
    assert not problemas, f"Vídeos com problema: {problemas}"


def test_links_externos_alcancaveis(client):
    externos = {u for u in _coletar_links(client) if "piplanner.io" not in u}
    inacessiveis = []
    for u in externos:
        try:
            r = client.head(u, timeout=15)
            if r.status_code >= 400 and r.status_code not in (403, 405, 999):
                r = client.get(u, timeout=15)
                if r.status_code >= 400 and r.status_code not in (403, 405, 999):
                    inacessiveis.append(f"{r.status_code} {u}")
        except Exception as e:
            inacessiveis.append(f"ERRO {u}: {type(e).__name__}")
    assert not inacessiveis, f"Links externos inacessíveis: {inacessiveis}"


def test_rota_inexistente_tratada(client):
    r = client.get(BASE_URL + "/rota-que-nao-existe-qa-123", follow_redirects=False)
    assert r.status_code < 500

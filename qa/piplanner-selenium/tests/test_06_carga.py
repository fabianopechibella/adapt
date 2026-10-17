"""Teste de carga/estresse controlado — somente leitura, com parada de segurança.

A carga sobe em degraus (5, 10, 20, 30 requisições simultâneas) contra endpoints
GET públicos e autenticados. Para automaticamente se a taxa de erro passar de 20%
ou a latência média passar de 5s, para não impactar a produção do cliente.
Resultados gravados em relatorios/carga.json.
"""
import os
import json
import time
import pathlib
import statistics
import concurrent.futures as cf
import pytest
import httpx

BASE_URL = os.environ.get("BASE_URL", "https://piplanner.io").rstrip("/")
QA_USER = os.environ.get("QA_USER", "")
QA_PASS = os.environ.get("QA_PASS", "")
PROXY = os.environ.get("HTTPS_PROXY", "") or None
REL = pathlib.Path(__file__).parent.parent / "relatorios"
REL.mkdir(exist_ok=True)

DEGRAUS = [5, 10, 20, 30]
REQS_POR_DEGRAU = 60
LIMITE_ERRO = 0.20
LIMITE_LATENCIA = 5.0

pytestmark = pytest.mark.skipif(not (QA_USER and QA_PASS), reason="QA_USER/QA_PASS necessários")


def _auth():
    with httpx.Client(base_url=BASE_URL, proxy=PROXY, timeout=30, verify=False) as c:
        r = c.post("/api/auth/login", json={"email": QA_USER, "password": QA_PASS})
    if r.status_code == 429:
        pytest.skip("Login limitado por tentativas (429); rode o teste de carga isolado")
    assert r.status_code == 200, f"Login falhou: {r.status_code}"
    u = r.json()["user"]
    return {"Authorization": f"Bearer {u['id']}:{u['organization_id']}"}


def _uma_req(headers, caminho):
    t0 = time.time()
    try:
        with httpx.Client(base_url=BASE_URL, proxy=PROXY, timeout=20, verify=False) as c:
            r = c.get(caminho, headers=headers)
        return (r.status_code, time.time() - t0)
    except Exception:
        return (0, time.time() - t0)


def test_carga_progressiva():
    headers = _auth()
    caminhos = ["/api/pi-plannings", "/api/risks", "/api/teams", "/api/strategic-objectives", "/"]
    resultados = []
    parou = None
    for conc in DEGRAUS:
        lats, status = [], []
        with cf.ThreadPoolExecutor(max_workers=conc) as ex:
            futuros = [ex.submit(_uma_req, headers, caminhos[i % len(caminhos)]) for i in range(REQS_POR_DEGRAU)]
            for f in cf.as_completed(futuros):
                sc, lat = f.result()
                status.append(sc); lats.append(lat)
        erros = sum(1 for s in status if s == 0 or s >= 500)
        taxa_erro = erros / len(status)
        taxa_429 = sum(1 for s in status if s == 429) / len(status)
        degrau = {
            "concorrencia": conc, "requisicoes": len(status),
            "taxa_erro_5xx": round(taxa_erro, 3), "taxa_429": round(taxa_429, 3),
            "latencia_media_s": round(statistics.mean(lats), 3),
            "latencia_p95_s": round(sorted(lats)[int(len(lats) * 0.95)], 3),
            "latencia_max_s": round(max(lats), 3),
        }
        resultados.append(degrau)
        if taxa_erro > LIMITE_ERRO or statistics.mean(lats) > LIMITE_LATENCIA:
            parou = f"Parada de segurança no degrau {conc}: erro={taxa_erro:.0%}, latência média={statistics.mean(lats):.1f}s"
            break
        time.sleep(3)  # alívio entre degraus

    saida = {"base_url": BASE_URL, "degraus": resultados, "parada_seguranca": parou}
    (REL / "carga.json").write_text(json.dumps(saida, indent=2, ensure_ascii=False))
    # Não falha o teste por 429 (é proteção esperada); falha só por erro de servidor sustentado.
    pico = resultados[-1]
    assert pico["taxa_erro_5xx"] <= LIMITE_ERRO, f"Erro 5xx acima do limite sob carga: {pico}"

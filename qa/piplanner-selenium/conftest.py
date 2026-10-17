"""Configuração compartilhada da bateria Selenium para https://piplanner.io.

Credenciais vêm só de variáveis de ambiente (QA_USER / QA_PASS); nunca ficam no código.
Cada teste captura screenshot de evidência; falhas também geram screenshot automático.
Modo somente leitura por padrão: escritas na API são bloqueadas no navegador.
"""
import os
import time
import pathlib
import datetime as dt
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options

BASE_URL = os.environ.get("BASE_URL", "https://piplanner.io").rstrip("/")
QA_USER = os.environ.get("QA_USER", "")
QA_PASS = os.environ.get("QA_PASS", "")
CHROMEDRIVER = os.environ.get("CHROMEDRIVER", "/tmp/claude-0/drv/chromedriver-linux64/chromedriver")
CHROME_BIN = os.environ.get("CHROME_BIN", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
PROXY = os.environ.get("HTTPS_PROXY", "")
EVID = pathlib.Path(__file__).parent / "evidencias"
EVID.mkdir(exist_ok=True)


def _make_driver(width=1366, height=900, mobile=False):
    opts = Options()
    opts.binary_location = CHROME_BIN
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--ignore-certificate-errors")
    opts.add_argument(f"--window-size={width},{height}")
    opts.add_argument("--lang=pt-BR")
    if PROXY:
        opts.add_argument(f"--proxy-server={PROXY}")
    if mobile:
        opts.add_experimental_option("mobileEmulation", {"deviceName": "Pixel 7"})
    opts.set_capability("goog:loggingPrefs", {"browser": "ALL", "performance": "ALL"})
    d = webdriver.Chrome(service=Service(CHROMEDRIVER), options=opts)
    d.set_page_load_timeout(60)
    return d


@pytest.fixture
def driver():
    d = _make_driver()
    yield d
    d.quit()


@pytest.fixture
def mobile_driver():
    d = _make_driver(390, 844, mobile=True)
    yield d
    d.quit()


def shot(driver, name):
    """Salva screenshot de evidência com carimbo de data/hora."""
    ts = dt.datetime.now().strftime("%H%M%S")
    path = EVID / f"{name}-{ts}.png"
    driver.save_screenshot(str(path))
    return path


@pytest.fixture(autouse=True)
def _screenshot_on_failure(request, driver=None):
    yield
    drv = request.node.funcargs.get("driver") or request.node.funcargs.get("mobile_driver")
    rep = getattr(request.node, "rep_call", None)
    if drv and rep and rep.failed:
        shot(drv, f"FALHA-{request.node.name}")


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()
    setattr(item, f"rep_{rep.when}", rep)

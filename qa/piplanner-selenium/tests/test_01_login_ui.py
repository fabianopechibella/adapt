"""Testes de UI (Selenium) — autenticação. Evidência em screenshot por teste."""
import os
import pytest
from selenium.webdriver.common.by import By
from conftest import BASE_URL, QA_USER, QA_PASS, shot
from pages.login_page import LoginPage

pytestmark = pytest.mark.skipif(not (QA_USER and QA_PASS), reason="QA_USER/QA_PASS necessários")


def test_pagina_login_carrega(driver):
    lp = LoginPage(driver, BASE_URL).open("/login")
    lp.wait_visible(LoginPage.EMAIL)
    assert driver.find_element(*LoginPage.PASSWORD)
    assert driver.find_element(*LoginPage.SUBMIT)
    shot(driver, "login-carregada")


def test_login_valido_entra_no_painel(driver):
    lp = LoginPage(driver, BASE_URL).login(QA_USER, QA_PASS)
    lp.wait_url_not_contains("/login")
    shot(driver, "login-valido-dashboard")
    assert "/login" not in driver.current_url


def test_login_senha_errada_nao_entra(driver):
    lp = LoginPage(driver, BASE_URL).login(QA_USER, "SenhaErrada123")
    import time; time.sleep(2)
    shot(driver, "login-senha-errada")
    assert "/login" in driver.current_url


def test_login_senha_sem_numero_rejeitada(driver):
    lp = LoginPage(driver, BASE_URL).login(QA_USER, "semnumero")
    import time; time.sleep(1)
    shot(driver, "login-senha-sem-numero")
    assert "/login" in driver.current_url


def test_rota_protegida_sem_sessao_redireciona(driver):
    driver.get(BASE_URL + "/UserManagement")
    import time; time.sleep(3)
    shot(driver, "rota-protegida-sem-sessao")
    assert "/login" in driver.current_url

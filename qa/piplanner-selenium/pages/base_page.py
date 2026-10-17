"""Classe base dos Page Objects (padrão Page Object Model)."""
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By


class BasePage:
    def __init__(self, driver, base_url):
        self.driver = driver
        self.base_url = base_url

    def open(self, path=""):
        self.driver.get(self.base_url + path)
        return self

    def wait_visible(self, locator, timeout=20):
        return WebDriverWait(self.driver, timeout).until(EC.visibility_of_element_located(locator))

    def wait_url_contains(self, text, timeout=20):
        WebDriverWait(self.driver, timeout).until(EC.url_contains(text))

    def wait_url_not_contains(self, text, timeout=30):
        WebDriverWait(self.driver, timeout).until_not(EC.url_contains(text))

    def wait_app_ready(self, timeout=30):
        """Espera o indicador 'Carregando...' da SPA desaparecer."""
        from selenium.webdriver.support.ui import WebDriverWait as W
        try:
            W(self.driver, timeout).until(
                lambda d: "carregando" not in d.find_element(By.TAG_NAME, "body").text.lower()[:200]
            )
        except Exception:
            pass

    def read_only_api(self):
        """Via CDP, aborta toda escrita na API (POST/PUT/PATCH/DELETE), menos o login."""
        self.driver.execute_cdp_cmd("Network.enable", {})
        self.driver.execute_cdp_cmd("Network.setRequestInterception", {"patterns": [{"urlPattern": "*/api/*"}]}) \
            if False else None
        return self

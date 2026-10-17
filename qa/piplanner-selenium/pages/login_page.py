"""Page Object da tela de login."""
from selenium.webdriver.common.by import By
from .base_page import BasePage


class LoginPage(BasePage):
    EMAIL = (By.CSS_SELECTOR, 'input[name="email"], input[type="email"]')
    PASSWORD = (By.CSS_SELECTOR, 'input[name="password"], input[type="password"]')
    SUBMIT = (By.CSS_SELECTOR, 'form button[type="submit"]')

    def login(self, email, password):
        self.open("/login")
        self.wait_visible(self.EMAIL).send_keys(email)
        self.driver.find_element(*self.PASSWORD).send_keys(password)
        self.driver.find_element(*self.SUBMIT).click()
        return self

    def error_text(self):
        body = self.driver.find_element(By.TAG_NAME, "body").text
        return body

import os
import requests
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import logging

#Phase 1: Scraping. 
#Case: The TP-link Download Center.


# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def setup_driver():
    options = Options()
    options.headless = False  # Set to True if you want to run headless
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    return driver

def get_product_links(driver, main_url):
    try:
        logging.info(f"Accessing main download page: {main_url}")
        driver.get(main_url)
        product_links = []

        WebDriverWait(driver, 20).until(
            EC.presence_of_all_elements_located((By.CSS_SELECTOR, 'a[href^="/dk/support/download/"]'))
        )

        elements = driver.find_elements(By.CSS_SELECTOR, 'a[href^="/dk/support/download/"]')
        for elem in elements:
            product_link = elem.get_attribute('href')
            if product_link.startswith('/'):
                product_link = 'https://www.tp-link.com' + product_link
            product_links.append(product_link)

        logging.info(f"Found {len(product_links)} product links.")
        return product_links

    except Exception as e:
        logging.error(f"Error getting product links: {e}")
        return []

def get_firmware_links(driver, product_url):
    try:
        logging.info(f"Accessing product page: {product_url}")
        driver.get(product_url)
        firmware_links = []

        WebDriverWait(driver, 20).until(
            EC.presence_of_all_elements_located((By.CSS_SELECTOR, 'a[href$=".zip"]'))
        )

        elements = driver.find_elements(By.CSS_SELECTOR, 'a[href$=".zip"]')
        for elem in elements:
            firmware_link = elem.get_attribute('href')
            firmware_links.append(firmware_link)

        logging.info(f"Found {len(firmware_links)} firmware links on {product_url}.")
        return firmware_links

    except Exception as e:
        logging.error(f"Error getting firmware links from {product_url}: {e}")
        return []

def download_file(url, folder='firmware_downloads'):
    try:
        if not os.path.exists(folder):
            os.makedirs(folder)
        local_filename = os.path.join(folder, url.split('/')[-1])
        with requests.get(url, stream=True) as r:
            r.raise_for_status()
            with open(local_filename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        logging.info(f'Downloaded: {local_filename}')
    except Exception as e:
        logging.error(f"Error downloading file {url}: {e}")

def scrape_firmware(main_url):
    driver = setup_driver()
    try:
        product_links = get_product_links(driver, main_url)
        for product_link in product_links:
            logging.info(f'Starting to scrape firmware from {product_link}')
            firmware_links = get_firmware_links(driver, product_link)
            for firmware_link in firmware_links:
                logging.info(f'Downloading firmware from {firmware_link}')
                download_file(firmware_link)
        logging.info("Completed scraping all firmware.")
    finally:
        driver.quit()

if __name__ == '__main__':
    MAIN_URL = 'https://www.tp-link.com/dk/support/download/'
    logging.info("Starting the firmware scraping process.")
    scrape_firmware(MAIN_URL)
    logging.info("Firmware scraping process completed.")

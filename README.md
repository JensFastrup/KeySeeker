# KeySeeker
KeySeeker aims at creating a safer space for developers and enables security to asses if their firmware are leaking cryptographic material publicy on the web.
Before using this tool, ensure you have the required permissions and consider the legalities. The author takes no responsibility in misuse of this software as it is purely meant for research only. 

The tool is three part. 
1. scraper.py, utilizes Selenium to dynamically scrape firmware products from a page, take a download center.
2. analyzer.sh, utilizes Binwalk to extract the firmware and perform analysis of cryptographic material.
3. comitter.sh, sophisitcates intermedatiate results from the analyzer and looks for key-pairs. There lies responibility for this in the future. 

KeySeeker is a Master Thesis project by Jens Michael Sarro Fastrup of IT-Univeristy of Copenhagen. This project is under supervision of Carsten Schürmann, Professor of Computer Science @ ITU.

## Setup
- Clone the repo.
- setup virtual environment and download relevant packages as seen in requirements.txt
- This tool is developed on a Linux-based platform, so no guarantees for Windows or macOS.
- adjust scraper.py to your vendor page, check and see what url-links/keywords are connected to your type.
- If successful, run analyser.sh. Depending on the size and amount firmware, this can take time.
- If successful, you can either browsw intermediate results, or run comitter.sh to collect key-pairs.

  

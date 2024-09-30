![KeySeeker](https://github.com/JensFastrup/KeySeeker/blob/main/keyseeker.PNG)


# KeySeeker
KeySeeker aims at creating a safer space for developers and enables security to asses if their firmware are leaking secret cryptographic material publicy on the web.
Before using this tool, ensure you have the required permissions and consider the legalities. The author takes no responsibility in misuse of this software or distribution of results as it is purely meant for research only. 

The tool is three part. 
1. scraper.py, utilizes selenium to dynamically scrape firmware products from a page, take a download center.
2. analyzer.sh, utilizes binwalk to extract the firmware and perform analysis of cryptographic material.
3. comitter.sh, sophisitcates intermedatiate results from the analyzer and looks for key-pairs. There lies responibility for this in the future. 

KeySeeker is a Master Thesis project by Jens Michael Sarro Fastrup of IT-Univeristy of Copenhagen. This project is under supervision of Carsten Schürmann, Professor of Computer Science @ ITU.

## Setup
- Clone the repo.
- setup virtual environment and download relevant packages as seen in requirements.txt. Likewise
- Install binwalk and openssl (sudo apt update) (sudo apt install binwalk openssl)
- This tool is developed on a Linux-based platform and run as a cmd-line tool, so no guarantees for Windows or macOS.
- Adjust scraper.py to your vendor page, check and see what url-links/keywords are connected to your type.
- If successful, run ./analyser.sh. Depending on the size and amount firmware, this can take time.
- If successful, you can either browse intermediate results, or run ./comitter.sh to collect key-pairs.
- If experiencing issues, consider if is a PATH problem/missing packages or not running as root-user.  

## Futher use
- Recommendably, use badkeys to analyze keys collected to expose known vulnerabilities, such as weak exponent or leaked keys. Link: [badkeys](https://github.com/badkeys/badkeys)

- Dive deep in the firmware, consider analyzing the firmware with FACT, read more: [FACT](https://github.com/fkie-cad/FACT_core)

## Challenges & Considerations
- How do we balance scraping *all* material vs running efficiently when considering large domains containging hundreds or thousands of pieces of firmware? 

- How do we ensure that all cryptographic material has been sufficiently collected - and how can we learn of their uses? 

- Can the collected material be organized to offer better knowledge of the structure/infrastructure of the product?

 

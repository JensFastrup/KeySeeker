#!/bin/bash

# Phase 2: The Analyzer

# Input URL and destination path passed as arguments to the script
# Example: from https://www.tp-link.com/us/support/download/archer-ax20/.
 
# ./program.sh https://static.tp-link.com/upload/firmware/2023/202308/20230814/Archer%20AX20(US)_V4.6_230725.zip?_gl=1*15f8zih*
#_ga*MjAwMTY3MjI1OS4xNzE1MTU5ODAw*_ga_X5XJFE5K24*MTcxNTYxMDAyMi40LjEuMTcxNTYxMDA4NS4wLjAuMA.. /home/kali/Desktop/Firmscraper/firmscraper/firmware.zip

#Ensure these are downloaded: 
# sudo apt update
# sudo apt install binwalk openssl

# Check if required tools are installed
for tool in binwalk openssl wget; do
    if ! command -v $tool &> /dev/null; then
        echo "$tool could not be found. Please install it and try again."
        exit 1
    fi
done

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
FIRMWARE_DIR="$SCRIPT_DIR/firmware_downloads"
EXTRACTION_PATH="$SCRIPT_DIR/extracted"
RESULTS_PATH="$SCRIPT_DIR/results"
DEVICES_FOLDER="$RESULTS_PATH/devices_folder"
SUMMARY_FILE="$RESULTS_PATH/summary_file.txt"
LOG_FILE="$RESULTS_PATH/findings.log"
ANALYZED_FILES="$RESULTS_PATH/analyzed_files.txt"

mkdir -p "$EXTRACTION_PATH"
mkdir -p "$RESULTS_PATH"
mkdir -p "$DEVICES_FOLDER"

# Initialize summary, log, and analyzed files
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "Summary of Findings" > "$SUMMARY_FILE"
    echo "===================" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "Findings log:" > "$LOG_FILE"
    echo "===================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

if [ ! -f "$ANALYZED_FILES" ]; then
    echo "Analyzed Files:" > "$ANALYZED_FILES"
    echo "===================" >> "$ANALYZED_FILES"
    echo "" >> "$ANALYZED_FILES"
fi

# Remove previous summary lines if they exist
sed -i '/^=======================/d' "$ANALYZED_FILES"
sed -i '/^Total firmware files analyzed:/d' "$ANALYZED_FILES"

# Function to create file summary
function create_file_summary {
    local file_path="$1"
    local device_folder="$2"
    
    local file_name=$(basename "$file_path")
    local file_size=$(stat -c%s "$file_path")
    local file_md5=$(md5sum "$file_path" | awk '{print $1}')
    local file_info=""

    if [[ "$file_name" == *\.cer || "$file_name" == *\.crt || "$file_name" == *\.cert ]]; then
        local cert_info=$(timeout 60s openssl x509 -in "$file_path" -noout -subject -issuer -dates 2>/dev/null)
        file_info=$(echo -e "\nCertificate Info:\n$cert_info")
    elif [[ "$file_name" == *\.key ]]; then
        local key_info=$(timeout 60s openssl pkey -in "$file_path" -noout -text 2>/dev/null)
        file_info=$(echo -e "\nKey Info:\n$key_info")
    elif [[ "$file_name" == *\.pem ]]; then
        if timeout 60s openssl x509 -in "$file_path" -noout &>/dev/null; then
            local cert_info=$(timeout 60s openssl x509 -in "$file_path" -noout -subject -issuer -dates 2>/dev/null)
            file_info=$(echo -e "\nCertificate Info:\n$cert_info")
        elif timeout 60s openssl pkey -in "$file_path" -noout &>/dev/null; then
            local key_info=$(timeout 60s openssl pkey -in "$file_path" -noout -text 2>/dev/null)
            file_info=$(echo -e "\nKey Info:\n$key_info")
        fi
    elif [[ "$file_name" == *\.pub ]]; then
        local pubkey_info=$(timeout 60s openssl pkey -pubin -in "$file_path" -noout -text 2>/dev/null)
        file_info=$(echo -e "\nPublic Key Info:\n$pubkey_info")
    fi

    echo "File: $file_name" >> "$device_folder/file_summary.txt"
    echo "Size: $file_size bytes" >> "$device_folder/file_summary.txt"
    echo "MD5: $file_md5" >> "$device_folder/file_summary.txt"
    echo -e "$file_info" >> "$device_folder/file_summary.txt"
    echo "" >> "$device_folder/file_summary.txt"
    echo "*-----------------------------------*" >> "$device_folder/file_summary.txt"
}

# Function to search and extract files
function search_and_extract {
    local path="$1"
    local device_folder="$2"
    declare -A hash_check  # Store hashes to prevent duplicates within the same device folder
    local embedded_count=0

    echo "DEBUG: Searching in path $path for device folder $device_folder"

    find "$path" -type f -print0 | while IFS= read -r -d $'\0' filename; do
        local file_type=$(file "$filename")
        
        if echo "$filename" | grep -Eiq '\.key$|\.pem$|\.pfx$|\.p12$|\.pub$'; then
            local content_hash=$(md5sum "$filename" | awk '{print $1}')
            if [ -z "${hash_check[$content_hash]}" ]; then
                mkdir -p "$device_folder"
                cp "$filename" "$device_folder/"
                create_file_summary "$filename" "$device_folder"
                echo "$filename found and copied to $device_folder." >> "$LOG_FILE"
                echo "DEBUG: Copied $filename to $device_folder"
                hash_check[$content_hash]=1
            fi
        elif echo "$filename" | grep -Eiq '\.cer$|\.crt$|\.cert$|\.ca-bundle$|\.p7b$|\.p7s$|\.der$'; then
            local content_hash=$(md5sum "$filename" | awk '{print $1}')
            if [ -z "${hash_check[$content_hash]}" ]; then
                mkdir -p "$device_folder"
                cp "$filename" "$device_folder/"
                create_file_summary "$filename" "$device_folder"
                echo "$filename found and copied to $device_folder." >> "$LOG_FILE"
                echo "DEBUG: Copied $filename to $device_folder"
                hash_check[$content_hash]=1
            fi
        fi
        
        if echo "$file_type" | grep -q 'ASCII text'; then
            grep -Pzo '(?s)-----BEGIN (PRIVATE KEY|CERTIFICATE|PUBLIC KEY|DSA PRIVATE KEY|ED25519 PRIVATE KEY|ED25519 PUBLIC KEY)-----.*?-----END (PRIVATE KEY|CERTIFICATE|PUBLIC KEY|DSA PRIVATE KEY|ED25519 PRIVATE KEY|ED25519 PUBLIC KEY)-----' "$filename" | while IFS= read -r -d '' block_content; do
                local block_hash=$(echo "$block_content" | md5sum | awk '{print $1}')
                
                if [ -n "$block_content" ] && [ -z "${hash_check[$block_hash]}" ]; then
                    mkdir -p "$device_folder"
                    local block_type=$(echo "$block_content" | grep -oP '(?<=BEGIN )[A-Z ]+(?=-----)')
                    local block_extension=""
                    
                    if [[ "$block_type" == "PRIVATE KEY" || "$block_type" == "DSA PRIVATE KEY" || "$block_type" == "ED25519 PRIVATE KEY" ]]; then
                        block_extension="key"
                    elif [[ "$block_type" == "CERTIFICATE" ]]; then
                        block_extension="cer"
                    elif [[ "$block_type" == "PUBLIC KEY" || "$block_type" == "ED25519 PUBLIC KEY" ]]; then
                        block_extension="pub"
                    fi

                    local block_file="$device_folder/$(basename "$filename" | cut -d. -f1)_${embedded_count}.${block_extension}"
                    echo "$block_content" > "$block_file"
                    create_file_summary "$block_file" "$device_folder"
                    echo "$filename contains embedded $block_type. Extracted to $block_file." >> "$LOG_FILE"
                    echo "DEBUG: Extracted embedded content from $filename to $block_file"
                    hash_check[$block_hash]=1
                    embedded_count=$((embedded_count + 1))
                fi
            done
        fi
    done
}

# Function to handle exit and cleanup
function on_exit {
    echo "Script interrupted. Saving state..."
    echo "=======================" >> "$ANALYZED_FILES"
    echo "Total firmware files analyzed: $analyzed_firmware_count" >> "$ANALYZED_FILES"
    echo "Script exited at $(date)" >> "$LOG_FILE"
    exit 0
}

# Trap interruptions and handle them
trap on_exit SIGINT SIGTERM

# Main processing loop
analyzed_firmware_count=$(grep -c -e '^Firmware File:' "$ANALYZED_FILES")
total_files=$(find "$FIRMWARE_DIR"/*.zip -type f | wc -l)

for firmware_file in "$FIRMWARE_DIR"/*.zip; do
    if [[ -f "$firmware_file" ]]; then
        firmware_name=$(basename "$firmware_file")
        
        # Skip already analyzed files
        if grep -q -F "$firmware_name" "$ANALYZED_FILES"; then
            echo "Skipping already analyzed file: $firmware_name"
            continue
        fi
        
        device_folder="$DEVICES_FOLDER/${firmware_name%.*}_results"
        echo "Processing firmware: $firmware_name"
        echo "Firmware File: $firmware_name" >> "$ANALYZED_FILES"
        ((analyzed_firmware_count++))

        extraction_subdir="$EXTRACTION_PATH/$firmware_name"
        mkdir -p "$extraction_subdir"
        
        timeout 300s binwalk -Me "$firmware_file" -C "$extraction_subdir" --run-as=root

        search_and_extract "$extraction_subdir" "$device_folder"

        # Clean up the extraction directory to save space
        rm -rf "$extraction_subdir"

        # Display progress
        echo "$analyzed_firmware_count/$total_files files analyzed."
    fi
done

# Summarize findings
echo "=======================" >> "$ANALYZED_FILES"
echo "Total firmware files analyzed: $analyzed_firmware_count" >> "$ANALYZED_FILES"

echo "Total number of analyzed firmware: $analyzed_firmware_count" >> "$SUMMARY_FILE"
echo "Total number of key files found: $(find "$DEVICES_FOLDER" -type f -name '*.key' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of cert files found: $(find "$DEVICES_FOLDER" -type f -name '*.cer' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of crt files found: $(find "$DEVICES_FOLDER" -type f -name '*.crt' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of cert files found: $(find "$DEVICES_FOLDER" -type f -name '*.cert' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of ca-bundle files found: $(find "$DEVICES_FOLDER" -type f -name '*.ca-bundle' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of p7b files found: $(find "$DEVICES_FOLDER" -type f -name '*.p7b' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of p7s files found: $(find "$DEVICES_FOLDER" -type f -name '*.p7s' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of der files found: $(find "$DEVICES_FOLDER" -type f -name '*.der' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of pfx files found: $(find "$DEVICES_FOLDER" -type f -name '*.pfx' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of p12 files found: $(find "$DEVICES_FOLDER" -type f -name '*.p12' | wc -l)" >> "$SUMMARY_FILE"
echo "Total number of pub files found: $(find "$DEVICES_FOLDER" -type f -name '*.pub' | wc -l)" >> "$SUMMARY_FILE"

echo "--------------------------" 
echo " "
echo "Extraction and search operations complete. See results directory for possible findings."
echo " "
echo "Script completed."
echo " "

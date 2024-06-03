#!/bin/bash
# Phase 3: The Comitter

set -e

RESULTS_DIR="results"
DEVICES_FOLDER="$RESULTS_DIR/devices_folder"
ORG_RESULTS_DIR="organized_results"
KEY_PAIRS_DIR="key_pairs"

mkdir -p "$ORG_RESULTS_DIR"
mkdir -p "$KEY_PAIRS_DIR"

create_meta_file() {
    local file_path="$1"
    local meta_file="$2"
    local uri=""
    local vendor="$3"
    local product="$4"
    local applies_to=""
    local applies_mask=""
    local password=""
    
    echo "uri=$uri" > "$meta_file"
    echo "vendor=$vendor" >> "$meta_file"
    echo "product=$product" >> "$meta_file"
    echo "applies_to=$applies_to" >> "$meta_file"
    echo "applies_mask=$applies_mask" >> "$meta_file"
    echo "password=$password" >> "$meta_file"
}

is_certificate_expired() {
    local cert_file="$1"
    local expiration_date=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
    local expiration_epoch=$(date -d "$expiration_date" +%s)
    local current_epoch=$(date +%s)

    if [ "$expiration_epoch" -lt "$current_epoch" ]; then
        return 0  
    else
        return 1  
    fi
}

#validate key-pairs 
process_device_files() {
    local device_folder="$1"
    local vendor="$2"
    local device="${3%_results}"

    local device_key_pair_dir="$KEY_PAIRS_DIR/$device"
    mkdir -p "$device_key_pair_dir"


    declare -A pub_keys
    declare -A priv_keys

    for file in "$device_folder"/*; do
        file_name=$(basename "$file")
        ext="${file_name##*.}"
        base_name="${file_name%.*}"

        if [[ "$file_name" == "file_summary.txt" ]]; then
            echo "Skipping file_summary.txt"
            continue
        fi

        case "$ext" in
            key)
                if openssl pkey -passin pass:'' -in "$file" -noout -text &>/dev/null; then
                    # Extract the public key
                    pub_key=$(openssl pkey -passin pass:'' -in "$file" -pubout -outform PEM 2>/dev/null)
                    priv_keys["$pub_key"]="$file"
                    new_name="${base_name}.key"
                    cp "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$new_name"
                    create_meta_file "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$base_name.meta" "$vendor" "$device"
                else
                    echo "Could not find private key of key from $file"
                fi
                ;;
            cer|crt|pem)
                if openssl x509 -in "$file" -noout -subject &>/dev/null; then
                    # Extract the public key and check expiration date 
                    #todo check that certificate is currently valid, not just expired. 
                    pub_key=$(openssl x509 -in "$file" -pubkey -noout -outform PEM 2>/dev/null)
                    if is_certificate_expired "$file"; then
                        echo "Skipping expired certificate: $file"
                        continue
                    fi
                    pub_keys["$pub_key"]="$file"
                    new_name="${base_name}.crt"
                    cp "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$new_name"
                    create_meta_file "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$base_name.meta" "$vendor" "$device"
                elif openssl pkey -passin pass:'' -in "$file" -noout -text &>/dev/null; then
                    # Extract the public key from PEM
                    pub_key=$(openssl pkey -passin pass:'' -in "$file" -pubout -outform PEM 2>/dev/null)
                    priv_keys["$pub_key"]="$file"
                    new_name="${base_name}.key"
                    cp "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$new_name"
                    create_meta_file "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$base_name.meta" "$vendor" "$device"
                else
                    echo "Could not decode PEM from $file"
                fi
                ;;
            pub)
                if openssl pkey -pubin -in "$file" -noout -text &>/dev/null; then
                    pub_key=$(openssl pkey -pubin -in "$file" -outform PEM 2>/dev/null)
                    pub_keys["$pub_key"]="$file"
                    new_name="${base_name}.pub"
                    cp "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$new_name"
                    create_meta_file "$file" "$ORG_RESULTS_DIR/$vendor/${device}_results/$base_name.meta" "$vendor" "$device"
                else
                    echo "Could not decode public key from $file"
                fi
                ;;
            meta|txt)
                echo "Skipping unsupported file type: $file"
                ;;
            *)
                echo "Skipping unsupported file type: $file"
                ;;
        esac
    done

    # Check for matching keys and certificates
    local matched_key_pairs=0
    for pub_key in "${!pub_keys[@]}"; do
        if [[ -n "${priv_keys[$pub_key]}" ]]; then
            cert_file="${pub_keys[$pub_key]}"
            key_file="${priv_keys[$pub_key]}"
            echo "Match found for device $device: $cert_file and $key_file"
            cp "$cert_file" "$device_key_pair_dir/"
            cp "$key_file" "$device_key_pair_dir/"

            create_meta_file "$cert_file" "$device_key_pair_dir/$(basename "${cert_file%.*}").meta" "$vendor" "$device"
            create_meta_file "$key_file" "$device_key_pair_dir/$(basename "${key_file%.*}").meta" "$vendor" "$device"
            matched_key_pairs=$((matched_key_pairs + 1))
        fi
    done

    if [ $matched_key_pairs -eq 0 ]; then
        rm -rf "$device_key_pair_dir"
    fi

    echo "$matched_key_pairs"
}

total_matched_key_pairs=0

for device_folder in "$DEVICES_FOLDER"/*; do
    if [ -d "$device_folder" ]; then
        device=$(basename "$device_folder")
        vendor=$(echo "$device" | cut -d'_' -f1)
        
        echo "Processing device folder: $device_folder"
        matched_key_pairs=$(process_device_files "$device_folder" "$vendor" "$device" | tail -n 1)
        total_matched_key_pairs=$((total_matched_key_pairs + matched_key_pairs))
    fi
done

echo "Total matched key-pairs: $total_matched_key_pairs"
echo "Organized results have been saved to $ORG_RESULTS_DIR."
echo "Key-pair results have been saved to $KEY_PAIRS_DIR."

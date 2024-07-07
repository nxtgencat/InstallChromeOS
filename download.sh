#!/bin/bash

get_file_size() {
    local url="$1"
    # Fetch headers to get content length
    curl -sI "$url" | grep -i '^Content-Length:' | tr -d '\r' | awk '{print $2}'
}

convert_bytes_to_mb() {
    local bytes="$1"
    # Convert bytes to megabytes
    awk "BEGIN { printf \"%.2f\n\", $bytes / (1024 * 1024) }"
}

download_file() {
    local url="$1"
    local output_file="${url##*/}"  # Extract filename from URL

    # Get file size in bytes
    local size_bytes=$(get_file_size "$url")
    if [ -z "$size_bytes" ]; then
        echo "Failed to get file size. Aborting."
        return 1
    fi

    # Convert size to megabytes
    local size_mb=$(convert_bytes_to_mb "$size_bytes")

    # Download the file with curl and show progress
    echo "Downloading $output_file ($size_mb MB)"
    curl -# -o "$output_file" "$url"
}

# Usage example
download_file "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_15572.63.0_rammus_recovery_stable-channel_mp-v3.bin.zip"

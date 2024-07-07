#!/bin/bash

# Function to extract a .zip file with progress indication using 7z
extract_zip_with_progress() {
    local file="$1"
    local temp_dir="/tmp/extract_temp"  # Temporary directory for extraction

    echo "Extracting $file..."

    # Create a temporary directory if it doesn't exist
    mkdir -p "$temp_dir"

    # Use 7z for extracting with progress
    7z x "$file" -o"$temp_dir" -bsp1

    # Move extracted files to destination directory or perform further processing
    mv "$temp_dir"/* /path/to/destination/

    # Clean up temporary directory
    rm -rf "$temp_dir"

    echo -e "\nExtraction completed successfully."
}

# Example usage:
filename="chromeos_15572.63.0_rammus_recovery_stable-channel_mp-v3.bin.zip"

# Call the function to extract the zip file with progress indication
extract_zip_with_progress "$filename"


#!/bin/bash

# Function to extract a .tar.gz file with progress
extract_tar_gz_with_progress() {
    local file="$1"

    echo "Extracting $file..."

    # Use pv (pipe viewer) if available to show progress, otherwise fallback to tar
    if command -v pv >/dev/null 2>&1; then
        pv "$file" | tar -xz
    else
        tar -xzf "$file"
    fi

    if [[ $? -eq 0 ]]; then
        echo "Extraction completed successfully."
    else
        echo "Error: Failed to extract $file."
    fi
}

# Example usage:
filename="brunch_r126_stable_20240630.tar.gz"

# Assuming the file is already downloaded, you can call the extraction function like this:
extract_tar_gz_with_progress "$filename"

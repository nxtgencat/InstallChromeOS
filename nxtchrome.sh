#!/bin/bash

# nxtspace
nxtspace() {
  nxtspace=ChromeOS
  mkdir -p "$nxtspace"
  cd "$nxtspace"
}

# Function to install dependencies based on environment
environment() {
  echo -e "\n- Installing Dependencies... \n"
  sleep 1
  if [ -n "$TERMUX_VERSION" ]; then
    echo -e "----------------------------------------\n"
    echo -e "- Running in Termux\n"
    pkg update && pkg install -y pv p7zip-full
    nxtspace
    purge
  elif [ -e "/etc/os-release" ]; then
    echo -e "----------------------------------------\n"
    echo -e "- Running in Linux Distro\n"
    sudo apt-get update && sudo apt-get install -y pv p7zip-full cgpt
    echo -e "----------------------------------------\n"
    if [ "$(uname -a | grep -i Microsoft)" ]; then
      echo -e "- Running In WSL Mode.\n"
      nxtspace
      purge
    elif grep -q "/cdrom" /etc/mtab; then
      echo -e "- Running In Live Mode.\n"
      mkdir -p /cdrom/ChromeOS
      cd /cdrom/ChromeOS
      purge    
    else
      echo -e "- Running In Installed Mode.\n"
      nxtspace
      purge
    fi
  fi
}

environment

# Function to get file size of a remote URL (following redirection)
get_remote_file_size() {
    local url="$1"
    curl -sI -L "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r'
}

# Function to get local file size
get_local_file_size() {
    local filename="$1"
    stat -c %s "$filename"
}

# Function to scrape latest version for a codename with retries
scrape_latest_version() {
    local codename="$1"
    local retries=3
    local latest_version=""

    while [[ $retries -gt 0 ]]; do
        # Define the URL
        URL="https://cros.tech/device/$codename/"

        # Use curl to fetch the webpage content and extract the latest version
        latest_version=$(curl -s "$URL" | grep -oP '>\d+</a>' | sed -e 's/>//' -e 's/<\/a>//' | sort -rn | head -n 1)

        # If latest_version is fetched successfully, break out of loop
        if [[ -n "$latest_version" ]]; then
            break
        fi

        ((retries--))
        sleep 1  # Optional delay before retrying
    done

    echo "$latest_version"
}

# Function to scrape latest link for a codename with retries
scrape_latest_link() {
    local codename="$1"
    local retries=3
    local latest_link=""

    while [[ $retries -gt 0 ]]; do
        # Define the URL
        URL="https://cros.tech/device/$codename/"

        # Use curl to fetch the webpage content and extract the latest link
        latest_link=$(curl -s "$URL" | grep -oP 'href="https://dl.google.com/dl/edgedl/chromeos/recovery/[^"]+"' | sort -rn | head -n 1 | cut -d '"' -f 2)

        # If latest_link is fetched successfully, break out of loop
        if [[ -n "$latest_link" ]]; then
            break
        fi

        ((retries--))
        sleep 1  # Optional delay before retrying
    done

    echo -e "\n$latest_link"
}

# Function to download the latest Brunch file
download_brunch() {
    local retries=3
    local download_url=""
    local filename=""

    # Define the repository owner and name
    REPO="sebanc/brunch"

    # Use GitHub API to get the latest release
    API_URL="https://api.github.com/repos/$REPO/releases/latest"

    while [[ $retries -gt 0 ]]; do
        # Fetch the release information
        RELEASE_INFO=$(curl -s "$API_URL")

        # Parse the release assets download URL and filename using grep and sed
        download_url=$(echo -e "\n$RELEASE_INFO" | grep '"browser_download_url":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)
        filename=$(basename "$download_url")

        # If download_url is fetched successfully, break out of loop
        if [[ -n "$download_url" ]]; then
            break
        fi

        ((retries--))
        sleep 1  # Optional delay before retrying
    done

    if [[ -n "$download_url" ]]; then
        echo -e "\nBrunch Download URL: $download_url"
        if check_and_download_github_file "$filename" "$download_url"; then
            echo -e "\nBrunch file downloaded successfully."
            extract_tar_gz_with_progress "$filename"
            return 0
        else
            echo -e "\nError: Could not fetch the Brunch download URL. Please try again later."
            return 1
        fi
    else
        echo -e "\nError: Could not fetch the Brunch download URL. Please try again later."
        return 1
    fi

    if [[ -f "$filename" ]]; then
        extract_tar_gz_with_progress "$filename"
    else
        echo -e "\nError: Could not fetch or extract $filename. Please try again later."
        return 1
    fi
}

# Function to check and download GitHub file
check_and_download_github_file() {
    local filename="$1"
    local url="$2"

    # Download the file if it doesn't exist or sizes don't match
    if [[ ! -f "$filename" ]]; then
        echo -e "\nDownloading $filename..."
        curl -LO "$url"
    else
        local remote_size
        local local_size

        # Get the redirected URL
        redirected_url=$(curl -sIL "$url" | grep -i '^location' | awk '{print $2}' | tr -d '\r')

        # Get remote and local file sizes
        remote_size=$(get_remote_file_size "$redirected_url")
        local_size=$(get_local_file_size "$filename")

        if [[ "$local_size" -eq "$remote_size" ]]; then
            echo -e "\nFile $filename already exists and its integrity is verified.."
        else
            echo -e "\nFile $filename exists but does not match the expected integrity. Redownloading..."
            curl -L -o "$filename" "$url"
        fi
    fi
}

# Function to check if file exists and matches the size of the online file for recovery images
check_and_download_recovery() {
    local filename="$1"
    local url="$2"
    local online_size

    # Get the online file size
    online_size=$(curl -sI "$url" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')

    if [[ -f "$filename" ]]; then
        local local_size
        local_size=$(stat -c %s "$filename")
        if [[ "$local_size" -eq "$online_size" ]]; then
            echo -e "\nFile $filename already exists and its integrity is verified.."
        else
            echo -e "\nFile $filename exists but does not match the expected integrity. Redownloading..."
            curl -L -o "$filename" "$url"
        fi
    else
        echo -e "\nFile $filename does not exist. Downloading..."
        curl -L -o "$filename" "$url"
    fi

    if [[ -f "$filename" ]]; then
        extract_zip_with_progress "$filename"
        binfilename="${filename%.zip}"
        mv "$binfilename" chromeos.bin
    else
        echo -e "\nError: Could not fetch or extract $filename. Please try again later."
        return 1
    fi
}

# Function to extract a .tar.gz file with progress
extract_tar_gz_with_progress() {
    local file="$1"

    echo -e "\nExtracting $file..."

    # Use pv (pipe viewer) if available to show progress, otherwise fallback to tar
    if command -v pv >/dev/null 2>&1; then
        pv "$file" | tar -xz
    else
        tar -xzf "$file"
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "\nExtraction completed successfully."
    else
        echo -e "\nError: Failed to extract $file."
    fi
}

# Function to extract a .zip file with progress indication using 7z
extract_zip_with_progress() {
    local file="$1"

    echo -e "\nExtracting $file..."

    # Use 7z for extracting
    7z x "$file"

    if [[ $? -eq 0 ]]; then
        echo -e "\nExtraction completed successfully."
    else
        echo -e "\nError: Failed to extract $file."
    fi
}

# Function to install ChromeOS into the system
os_install() {
echo -e "\e[96m┌────────────────────────────────────────────┐"
echo -e "│ ░█▀▀▄ ▀█▀ ░█▀▀▀█ ░█─▄▀ ░█▀▀█ ─█▀▀█ ░█▀▀█ ▀▀█▀▀ "
echo -e "│ ░█─░█ ░█─ ─▀▀▀▄▄ ░█▀▄─ ░█▄▄█ ░█▄▄█ ░█▄▄▀ ─░█ "
echo -e "│ ░█▄▄▀ ▄█▄ ░█▄▄▄█ ░█─░█ ░█─── ░█─░█ ░█─░█ ─░█ "
echo -e "└────────────────────────────────────────────┘\e[0m"
  sudo lsblk | grep -E 'disk|part' | awk '$1 !~ /loop/ {print}'
  echo -e "\n----------------------------------------\n"

  read -p "- Do you want to (i)nstall Chrome OS, (c)reate an ISO, or (q)uit ? : " action

  case $action in
    [iI])
      install_chromeos
      ;;
    [cC])
      create_iso
      ;;
    [qQ])
      echo -e "\n- Quitting the installation.\n"
      exit 0
      ;;
    *)
      echo -e "- Invalid choice. Please enter 'i', 'c', or 'q'."
      os_install
      ;;
  esac
}

# Function to install chromeos
install_chromeos() {
  echo
  read -p "- Do you want to install in the default location /sda? [ (y)es / (n)o / cust(o)m ]: " choice

  case $choice in
    [yY])
      echo -e "\n- Installing Chrome OS..."
      sudo bash chromeos-install.sh -src "chromeos.bin" -dst /dev/sda
        if [ $? -eq 0 ]; then
          echo -e "\n- Chrome OS Installation Completed. \n"
          exit 0
        else
           echo -e "\n- Chrome OS Not Installed. \n"
           exit 1
        fi
      ;;
    [oO])
      while true; do
        
        echo -e "\n "
        read -p "- Enter the desired installation location: /dev/" disk

        echo -e "\n- Installing Chrome OS..."
        sudo bash chromeos-install.sh -src "chromeos.bin" -dst "/dev/$disk"

        if [ $? -eq 0 ]; then
          echo -e "\n- Chrome OS Installation Completed. \n"
          exit 0
        else
          echo
          read -p "- An error occurred during installation. Do you want to try again? (y/n): " answer
          case $answer in
            [Yy]* ) continue;;
            * )
              echo -e "\n- Chrome OS Not Installed. \n"
              exit 1;; 
          esac
        fi
      done
      ;;
    [nN])
      echo -e "\n- Aborting installation.\n"
      exit 0
      ;;
    *)
      echo -e "- Invalid choice. Please enter 'y', 'n', or 'o'."
      os_install
      ;;
  esac
}

# Function to create iso
create_iso() {
  
  echo -e "\n- Creating Chrome OS ISO...\n"
  echo -e "\n- Initializing may take some time...\n"
  if [ "$(uname -a | grep -i Microsoft)" ]; then
  chromeisotemp=/mnt/c/ChromeOS
  rm -rf $chromeisotemp
  mkdir -p $chromeisotemp
  mv chromeos.bin efi_legacy.img efi_secure.img chromeos-install.sh rootc.img $chromeisotemp/
  cd $chromeisotemp
  sudo bash chromeos-install.sh -src chromeos.bin -dst $chromeisotemp/chromeos.img
  else
  sudo bash chromeos-install.sh -src chromeos.bin -dst chromeos.img
  fi

  if [ $? -eq 0 ]; then
    echo -e "\n- ChromeOS Installation IMG Saved $(pwd)/chromeos.img \n"
    echo -e "- Chrome OS ISO Creation Completed. \n"
    exit 0
  else
    echo -e "\n- Chrome OS ISO Creation Failed. \n"
    exit 1
  fi  
}

# Function to display the menu
show_menu() {
    clear
    echo -e "\e[96m┌──────────────────────────────────────────────────┐"
    echo -e "│ ░█▀▀█ ░█─░█ ░█▀▀█ ░█▀▀▀█ ░█▀▄▀█ ░█▀▀▀ ░█▀▀▀█ ░█▀▀▀█ "
    echo -e "│ ░█─── ░█▀▀█ ░█▄▄▀ ░█──░█ ░█░█░█ ░█▀▀▀ ░█──░█ ─▀▀▀▄▄ "
    echo -e "│ ░█▄▄█ ░█─░█ ░█─░█ ░█▄▄▄█ ░█──░█ ░█▄▄▄ ░█▄▄▄█ ░█▄▄▄█ "
    echo -e "└──────────────────────────────────────────────────┘\e[0m"
    echo -e "\n1. Intel 6th & 7th Gen    (Board: Rammus, Codename: Shyvana) - Latest Version: $(scrape_latest_version shyvana)"
    echo -e "\n2. Intel Celeron          (Board: Octopus, Codename: Bobba)  - Latest Version: $(scrape_latest_version bobba)"
    echo -e "\n3. Intel 10th Gen         (Board: Hatch, Codename: Jinlon)   - Latest Version: $(scrape_latest_version jinlon)"
    echo -e "\n4. Intel 11th Gen & Above (Board: Volteer, Codename: Voxel)  - Latest Version: $(scrape_latest_version voxel)"
    echo -e "\n5. AMD                    (Board: Zork, Codename: Gumboz)    - Latest Version: $(scrape_latest_version gumboz)"
    echo -e "\n6. Offline Install"
    echo -e "\n7. Exit\n"
}

# Main script
while true; do
    show_menu

    # Get user input
    echo -e "----------------------------------------\n"
    read -p "- Enter your choice: " choice
    echo -e "\n----------------------------------------\n"

    case $choice in
        1)
            codename="shyvana"
            latest_version=$(scrape_latest_version shyvana)
            if [[ -z "$latest_version" ]]; then
                echo -e "\nError: Could not fetch latest version for shyvana. Please try again later."
            else
                echo -e "\nCodename: shyvana - Latest Version: $latest_version"
                latest_link=$(scrape_latest_link shyvana)
                if [[ -z "$latest_link" ]]; then
                    echo -e "\nError: Could not fetch latest link for shyvana. Please try again later."
                else
                    echo -e "\nLink: $latest_link"
                    filename=$(basename "$latest_link")
                    if download_brunch && check_and_download_recovery "$filename" "$latest_link"; then
                        echo -e "\nBrunch and recovery image downloaded successfully."
                    fi
                fi
            fi
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        2)
            codename="bobba"
            latest_version=$(scrape_latest_version bobba)
            if [[ -z "$latest_version" ]]; then
                echo -e "\nError: Could not fetch latest version for bobba. Please try again later."
            else
                echo -e "\nCodename: bobba - Latest Version: $latest_version"
                latest_link=$(scrape_latest_link bobba)
                if [[ -z "$latest_link" ]]; then
                    echo -e "\nError: Could not fetch latest link for bobba. Please try again later."
                else
                    echo -e "\nLink: $latest_link"
                    filename=$(basename "$latest_link")
                    if download_brunch && check_and_download_recovery "$filename" "$latest_link"; then
                        echo -e "\nBrunch and recovery image downloaded successfully."
                    fi
                fi
            fi
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        3)
            codename="jinlon"
            latest_version=$(scrape_latest_version jinlon)
            if [[ -z "$latest_version" ]]; then
                echo -e "\nError: Could not fetch latest version for jinlon. Please try again later."
            else
                echo -e "\nCodename: jinlon - Latest Version: $latest_version"
                latest_link=$(scrape_latest_link jinlon)
                if [[ -z "$latest_link" ]]; then
                    echo -e "\nError: Could not fetch latest link for jinlon. Please try again later."
                else
                    echo -e "\nLink: $latest_link"
                    filename=$(basename "$latest_link")
                    if download_brunch && check_and_download_recovery "$filename" "$latest_link"; then
                        echo -e "\nBrunch and recovery image downloaded successfully."
                    fi
                fi
            fi
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        4)
            codename="voxel"
            latest_version=$(scrape_latest_version voxel)
            if [[ -z "$latest_version" ]]; then
                echo -e "\nError: Could not fetch latest version for voxel. Please try again later."
            else
                echo -e "\nCodename: voxel - Latest Version: $latest_version"
                latest_link=$(scrape_latest_link voxel)
                if [[ -z "$latest_link" ]]; then
                    echo -e "\nError: Could not fetch latest link for voxel. Please try again later."
                else
                    echo -e "\nLink: $latest_link"
                    filename=$(basename "$latest_link")
                    if download_brunch && check_and_download_recovery "$filename" "$latest_link"; then
                        echo -e "\nBrunch and recovery image downloaded successfully."
                    fi
                fi
            fi
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        5)
            codename="gumboz"
            latest_version=$(scrape_latest_version gumboz)
            if [[ -z "$latest_version" ]]; then
                echo -e "\nError: Could not fetch latest version for gumboz. Please try again later."
            else
                echo -e "\nCodename: gumboz - Latest Version: $latest_version"
                latest_link=$(scrape_latest_link gumboz)
                if [[ -z "$latest_link" ]]; then
                    echo -e "\nError: Could not fetch latest link for gumboz. Please try again later."
                else
                    echo -e "\nLink: $latest_link"
                    filename=$(basename "$latest_link")
                    if download_brunch && check_and_download_recovery "$filename" "$latest_link"; then
                        echo -e "\nBrunch and recovery image downloaded successfully."
                    fi
                fi
            fi
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        6)
            os_install
            read -p "- Press Enter to return to the menu."
            ;;
        7)
            echo -e "\nExiting..."
            break
            ;;
        *)
            echo -e "\nInvalid option. Please enter a valid option (1-7)."
            read -p "- Press Enter to continue."
            ;;
    esac
done

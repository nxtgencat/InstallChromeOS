#!/bin/bash

clear

# Fetch the raw file content
raw_file_url="https://raw.githubusercontent.com/nxtgencat/ChromeOS/main/chromeos"
raw_content=$(wget -qO - "$raw_file_url")

# Function to install dependencies based on environment
environment() {
  echo -e "\n- Installing Dependencies... \n"
  sleep 1
  if [ -n "$TERMUX_VERSION" ]; then
    echo -e "- Running in Termux\n"
    pkg update
    pkg install -y wget pv figlet
  elif [ -e "/etc/os-release" ]; then
    echo -e "- Running in Linux Distro\n"
    sudo apt-get update
    sudo apt-get install -y wget pv figlet
    echo -e "----------------------------------------\n"
    if grep -q "/cdrom" /etc/mtab; then
      echo -e "- Running In Live Mode.\n"
      mkdir -p /cdrom/ChromeOS
      cd /cdrom/ChromeOS
    else
      echo -e "- Running In Installed Mode.\n"
      mkdir ChromeOS
      cd ChromeOS
    fi
  fi
}

purge() {
  echo -e "- Purging Cache... \n"
  rm -rf *
}


environment

# Function to get version
version_get() {
  local codename=$1
  local version=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $3}')
  echo "(Stable: $version)"
}

# Function to install ChromeOS into the system
os_install() {
  echo
  read -p "- Do you want to install in the default location /sda ? (y/n/o): " choice

  case $choice in
    [yY])
      echo -e "\n- Installing Chrome OS..."
      sudo bash chromeos-install.sh -src "$codename.bin.zip" -dst /dev/sda
      echo -e "\n- Chrome OS Installation Completed. \n"
      exit 0
      ;;
    [oO])
      echo -e "----------------------------------------\n"
      echo -e "$(figlet -f small Disks)\n"
      echo -e "----------------------------------------\n"
      sudo lsblk | grep -E 'disk|part'
      echo -e "----------------------------------------\n"
      echo
      read -p "- Enter the desired installation location: /dev/" disk
      echo -e "\n- Installing Chrome OS..."
      sudo bash chromeos-install.sh -src "$codename.bin.zip" -dst "/dev/$disk"
      echo -e "\n- Chrome OS Installation Completed. \n"
      exit 0
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


# Function to install ChromeOS
chromeos_install() {
  local codename=$1
  local link=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $2}')

  if [ -n "$link" ]; then
    echo -e "\n- Fetching link ($codename) :\n$link\n"
    echo -e "- Downloading ChromeOS Files...\n"
    length=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')
     wget -q --show-progress -O "$codename.bin.zip" "$link"
     downloaded_size=$(wc -c < "$codename.bin.zip")
    
     if [ "$downloaded_size" -eq "$length" ]; then
       echo -e "- ChromeOS Files Downloaded\n"
       echo -e "- Extracting ChromeOS...\n"
       unzip "$codename.bin.zip" | pv -l >/dev/null
       original_name=$(unzip -Z -1 "$codename.bin.zip")
       mv "$original_name" chromeos.bin

       if [ -e "/etc/os-release" ]; then
         os_install
       else
         echo -e "\n- Unsupported Environment!"
         echo -e "\n- ChromeOS Not Installed.\n"
         purge
         exit 1
       fi
     else
       echo -e "\n- Error: ChromeOS Files Not Downloaded.\n"
       echo -e "\n- Aborting...\n"
       purge
       exit 1
     fi
  else
    echo -e "- Link Not Found For Codename: $codename\n"
    exit 1
  fi
}

# Function to install brunch
brunch_get() {
  local codename=$1
  local link=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $2}')

  if [ -n "$link" ]; then
    echo -e "\n- Fetching link ($codename) :\n$link\n"
    echo -e "- Downloading Brunch Framework...\n"
    length=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')
     wget -q --show-progress -O "$codename.tar.gz" "$link"
     downloaded_size=$(wc -c < "$codename.tar.gz")
    
     if [ "$downloaded_size" -eq "$length" ]; then
       echo -e "- Brunch Files Downloaded\n"
       echo -e "- Extracting Brunch Framework...\n"
       tar -xzvf "$codename.tar.gz"
       echo -e "\n- Extracted Brunch Framework \n"
     else
       echo -e "\n- Error: Brunch Framework Not Downloaded.\n"
       echo -e "\n- Aborting...\n"
       purge
       exit 1
     fi
  else
    echo -e "- Link Not Found For Codename: $codename\n"
    exit 1
  fi
}

# Function to display the menu
show_menu() {
  echo -e "----------------------------------------\n"
  echo -e "$(figlet -f small Chrome OS)\n"
  echo -e "----------------------------------------\n"
  echo -e "1. Intel 6th & 7th Gen $(version_get "shyvana") \n   (Board: Rammus, Codename: Shyvana)\n"
  echo -e "2. Intel Celeron $(version_get "bobba")\n   (Board: Octopus, Codename: Bobba)\n"
  echo -e "3. Intel 10th Gen $(version_get "jinlon")\n   (Board: Hatch, Codename: Jinlon)\n"
  echo -e "4. Intel 11th Gen & Above $(version_get "voxel")\n   (Board: Volteer, Codename: Voxel)\n"
  echo -e "5. AMD $(version_get "gumboz")\n   (Board: Zork, Codename: Gumboz)\n"
  echo -e "6. Exit\n"
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
      brunch_get "brunch"
      chromeos_install "shyvana"
      ;;
    2)
      brunch_get "brunch"
      chromeos_install "bobba"
      ;;
    3)
      brunch_get "brunch"
      chromeos_install "jinlon"
      ;;
    4)
      brunch_get "brunch"
      chromeos_install "voxel"
      ;;
    5)
      brunch_get "brunch"
      chromeos_install "gumboz"
      ;;
    6)
      echo -e "- Exiting the script. Goodbye!\n"
      exit 0
      ;;
    *)
      clear
      echo "- Invalid choice. Please retry with a valid option (1-6).\n"
      ;;
  esac
done



#nxtgencat
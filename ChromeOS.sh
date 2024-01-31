#!/bin/bash

clear
[ -f chromeos ] && rm -f chromeos
rm -rf LICENSE

# nxtspace
nxtspace() {
  nxtspace=ChromeOS
  mkdir -p "$nxtspace"
  cd "$nxtspace"
}

# Function to purge
purge() {
  echo -e "----------------------------------------\n"
  echo -e "- Purging Cache... \n"
  #rm -rf * /// not used
}

# Function to install dependencies based on environment
environment() {
  echo -e "\n- Installing Dependencies... \n"
  sleep 1
  if [ -n "$TERMUX_VERSION" ]; then
    echo -e "----------------------------------------\n"
    echo -e "- Running in Termux\n"
    pkg update && pkg install -y wget pv figlet unzip tar
    nxtspace
    purge
  elif [ -e "/etc/os-release" ]; then
    echo -e "----------------------------------------\n"
    echo -e "- Running in Linux Distro\n"
    sudo apt-get update && sudo apt-get install -y wget pv figlet cgpt unzip tar
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

# Fetch the raw file content
raw_file_url="https://raw.githubusercontent.com/nxtgencat/ChromeOS/main/chromeos"
raw_content=$(wget -qO - "$raw_file_url")


# Function to get version
version_get() {
  local codename=$1
  local version=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $3}')
  echo "(Stable: $version)"
}

# Function to extract tar with progress bar
extract_tar() {
 local userinputzipfile=$1
 tempdir="zipnxt"
 tempdirx="$tempdir/ziptemp"
 logfile="$tempdir/zipnxt.log"

 rm -rf "tempdir"
 mkdir -p "$tempdirx"
 # Function to display a progress bar
 show_progress_bar() {
   local width=50
   local percentage=$1
   local progress=$((width * percentage / 100))
   printf "[%-${width}s] %d%%\r" "$(printf '='%.0s $(seq "$progress"))" "$percentage"
  }

 # Unzip and show progress
 tar -ztvf "$userinputzipfile" | awk '{print $6, $3}' > "$logfile"
 total_size=$(awk '{sum += $2} END {print sum}' "$logfile")

 # Extract files
 tar -xzf "$userinputzipfile" -C "$tempdirx" &

 # Monitor progress
 while :; do
   completed_size=$(du --bytes --max-depth=0 "$tempdirx" | awk '{print $1}')
   progress_percentage=$((completed_size * 100 / total_size))
   show_progress_bar "$progress_percentage"

    if [[ "$completed_size" -ge "$total_size" ]]; then
      break
    fi
    sleep 1
  done
 mv -f "$tempdirx"/* .
 rm -rf "$tempdir"
}

# Function to extract zip with progress bar
extract_zip() {
 local userinputzipfile=$1
 tempdir="zipnxt"
 tempdirx="$tempdir/ziptemp"
 logfile="$tempdir/zipnxt.log"

 rm -rf "tempdir"
 mkdir -p "$tempdirx"

 # Function to display a progress bar
 show_progress_bar() {
   local width=50
   local percentage=$1
   local progress=$((width * percentage / 100))
   printf "[%-${width}s] %d%%\r" "$(printf '='%.0s $(seq "$progress"))" "$percentage"
  }

 # Unzip and show progress
 unzip -l "$userinputzipfile" | awk '{print $4, $1}' > "$logfile"
 total_size=$(awk '{sum += $2} END {print sum}' "$logfile")

 # Extract files
 unzip -q "$userinputzipfile" -d "$tempdirx" &

 # Monitor progress
 while :; do
   completed_size=$(du --bytes --max-depth=0 "$tempdirx" | awk '{print $1}')
   progress_percentage=$((completed_size * 100 / total_size))
   show_progress_bar "$progress_percentage"

   if [[ "$completed_size" -ge "$total_size" ]]; then
     break
   fi
   sleep 1
  done

 mv -f "$tempdirx"/* .
 rm -rf "$tempdir"
}

# Function to install ChromeOS into the system
os_install() {
  echo -e "----------------------------------------\n"
  echo -e "$(figlet -f small Diskpart)\n"
  echo -e "----------------------------------------\n"
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
        
        echo " "
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


# Function to download and extract Brunch OS files
brunch_get() {
  local codename=$1
  local link=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $2}')

  if [ -n "$link" ]; then
    echo -e "\n- Fetching link ($codename)\n"
    echo -e "- Checking if Brunch files exist...\n"

    if [ -e "$codename.tar.gz" ]; then
      local local_size=$(stat -c%s "$codename.tar.gz")
      local online_size=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')

      if [ "$local_size" -eq "$online_size" ]; then
        echo -e "- Brunch Files already exist and integrity has been verified.\n"
      else
        echo -e "- Brunch Files exist but Integrity check failed.\n"
        echo -e "- Re-downloading...\n"
        rm -f "$codename.tar.gz"
        download_and_extract_brunch "$link" "$codename"
      fi
    else
      echo -e "- Brunch Files do not exist. Downloading...\n"
      download_and_extract_brunch "$link" "$codename"
    fi
  else
    echo -e "- Link Not Found For Codename: $codename\n"
    exit 1
  fi
}

# Helper function to download and extract Brunch
download_and_extract_brunch() {
  local link="$1"
  local codename="$2"
  
  echo -e "- Downloading Brunch Framework...\n"
  wget -q --show-progress -O "$codename.tar.gz" "$link"

  local downloaded_size=$(stat -c%s "$codename.tar.gz")
  local online_size=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')


  if [ "$downloaded_size" -eq "$online_size" ]; then
    echo -e "\n- Brunch Files Downloaded\n"
    echo -e "- Extracting Brunch Framework...\n"
    extract_tar "$codename.tar.gz"
    if [ $? -eq 0 ]; then
      echo -e "\n\n- Extracted Brunch Framework \n"
    else
      echo -e "\n- Extraction Failed.\n"
      echo -e "\n- Aborting...\n"
      purge
      exit 1
    fi
  else
    echo -e "\n- Error: Brunch Framework Not Downloaded.\n"
    echo -e "\n- Aborting...\n"
    purge
    exit 1
  fi
}

# Function to download and extract Chrome OS files
chromeos_get() {
  local codename=$1
  local link=$(echo "$raw_content" | awk -v codename="$codename" '$1 == codename {print $2}')

  if [ -n "$link" ]; then
    echo -e "\n- Fetching link ($codename)\n"
    echo -e "- Checking if ChromeOS files exist...\n"

    if [ -e "$codename.bin.zip" ]; then
      local local_size=$(stat -c%s "$codename.bin.zip")
      local online_size=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')

      if [ "$local_size" -eq "$online_size" ]; then
        echo -e "- ChromeOS Files already exist and integrity has been verified.\n"
      else
        echo -e "- ChromeOS Files exist but Integrity check failed.\n"
        echo -e "- Re-downloading...\n"
        rm -f "$codename.bin.zip"
        download_and_extract_chromeos "$link" "$codename"
      fi
    else
      echo -e "- ChromeOS Files do not exist. Downloading...\n"
      download_and_extract_chromeos "$link" "$codename"
    fi

    if [ -e "/etc/os-release" ]; then
      os_install
    else
      echo -e "\n- Unsupported Environment!"
      echo -e "\n- ChromeOS Not Installed.\n"
      exit 1
    fi
  else
    echo -e "- Link Not Found For Codename: $codename\n"
    exit 1
  fi
}

# Helper function to download and extract ChromeOS
download_and_extract_chromeos() {
  local link="$1"
  local codename="$2"

  echo -e "- Downloading ChromeOS Files...\n"
  wget -q --show-progress -O "$codename.bin.zip" "$link"
  
  local downloaded_size=$(stat -c%s "$codename.tar.gz")
  local online_size=$(wget --spider "$link" 2>&1 | grep "Length" | awk '{print $2}')


  if [ "$downloaded_size" -eq "$online_size" ]; then
    echo -e "\n- ChromeOS Files Downloaded\n"
    echo -e "- Extracting ChromeOS Files...\n"
    extract_zip "$codename.bin.zip"
    if [ $? -eq 0 ]; then
      echo -e "\n\n- Extracted ChromeOS Files.\n"
      original_name=$(unzip -Z -1 "$codename.bin.zip")
      mv "$original_name" chromeos.bin
    else
      echo -e "\n- Extraction Failed.\n"
      echo -e "\n- Aborting...\n"
      purge
      exit 1
    fi
  else
    echo -e "\n- Error: ChromeOS Files Not Downloaded.\n"
    echo -e "\n- Aborting...\n"
    purge
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
  echo -e "6. Offline Install\n"
  echo -e "7. Exit\n"
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
      chromeos_get "shyvana"
      ;;
    2)
      brunch_get "brunch"
      chromeos_get "bobba"
      ;;
    3)
      brunch_get "brunch"
      chromeos_get "jinlon"
      ;;
    4)
      brunch_get "brunch"
      chromeos_get "voxel"
      ;;
    5)
      brunch_get "brunch"
      chromeos_get "gumboz"
      ;;
    6)
      os_install
      ;;
    7)
      echo -e "- Exiting the script. Goodbye!\n"
      exit 0
      ;;      
    *)
      clear
      echo -e "- Invalid choice. Please retry with a valid option (1-6)\n"
      ;;
  esac
done
#nxtgencat

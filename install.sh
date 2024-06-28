# Set the owner and repo variables
OWNER="radkesvat"
REPO="WaterWall"

# Determine the architecture and set the ASSET_NAME accordingly
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then
  ASSET_NAME="Waterwall-linux-arm64.zip"
elif [ "$ARCH" == "x86_64" ]; then
  ASSET_NAME="Waterwall-linux-64.zip"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Function to download and unzip the release
download_and_unzip() {
  local url="$1"
  local dest="$2"
  

  echo "Downloading $dest from $url..."
  wget -q -O "$dest" "$url"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to download file."
    return 1
  fi

  echo "Unzipping $dest..."
  unzip -o "$dest"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to unzip file."
    return 1
  fi

  sleep 0.5
  chmod +x Waterwall
  rm "$dest"

  echo "Download and unzip completed successfully."
}

get_latest_release_url() {
  local api_url="https://api.github.com/repos/$OWNER/$REPO/releases/latest"

  echo "Fetching latest release data..." >&2
  local response=$(curl -s "$api_url")
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data." >&2
    return 1
  fi

  local asset_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found." >&2
    return 1
  fi

  echo "$asset_url"
}

# Function to handle download and unzip process
handle_download_and_unzip() {
  local url=$(get_latest_release_url)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  download_and_unzip "$url" "$ASSET_NAME"
  core_config
}

# Function to configure core.json based on user input
core_config() {
  # Download core.json from GitHub
  local github_url="https://raw.githubusercontent.com/$OWNER/$REPO/master/core.json"
  local dest_file="core.json"

  echo "Downloading core.json from $github_url..."
  wget -q -O "$dest_file" "$github_url"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to download core.json."
    return 1
  fi

  # Prompt user for configuration inputs
  read -p "Enter number of workers (default 0): " workers
  read -p "Enter ram-profile (minimal/client/server, default server): " ram_profile

  # Set default values if user input is empty
  workers=${workers:-0}
  ram_profile=${ram_profile:-server}

  # Validate ram-profile input
  case $ram_profile in
    minimal|client|server)
      ;;
    *)
      echo "Invalid ram-profile value. Setting default to server."
      ram_profile="server"
      ;;
  esac

  # Update core.json with user inputs
  jq ".misc.workers = $workers | .misc.\"ram-profile\" = \"$ram_profile\"" "$dest_file" > temp.json && mv temp.json "$dest_file"

  echo "core.json updated successfully."
}

function main_menu {
    while true; do
        clear
        display_logo
        echo "Main Menu:"
        echo "1 - Iran"
        echo "2 - Kharej"
        echo "0 - Exit"
        read -p "Enter your choice: " main_choice
        case $main_choice in
            1)
                config_iran_server
                ;;
            2)
                config_kharej_server
                ;;
            0)
                exit 0
                ;;
            *)
                echo "Invalid choice, please try again."
                sleep 0.5
                ;;
        esac
    done
}


function config_iran_server {
    clear
    display_logo
    mkdir /root/RRT
    cd /root/RRT
    apt install unzip -y
    apt install jq -y
    
    handle_download_and_unzip
    local github_url="https://raw.githubusercontent.com/$OWNER/$REPO/master/iran_config.json"
    local dest_file="config.json"

    echo "Downloading config.json from $github_url..."
    wget -q -O "$dest_file" "$github_url"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to download config.json."
      return 1
    fi
    read -p "Enter Kharej IPv4: " kharej_ip
    read -p "Please enter your Sni. (It is better to use internal sites with ir domain): " sni

    echo "Kharej IP: $kharej_ip"
    echo "sni: $sni"

    jq --arg address "$kharej_ip" '.nodes[] | select(.name == "kharej_inbound") .settings.address = $address' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update config.json for kharej_inbound address."
      return 1
    fi

    jq --arg address "$sni" '.nodes[] | select(.name == "reality_dest") .settings.address = $address' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update config.json for reality_dest address."
      return 1
    fi

    echo "config.json updated successfully."

    read -p "Press enter to continue..."
    main_menu
}



function config_kharej_server {
    clear
    display_logo
    handle_download_and_unzip
    local github_url="https://raw.githubusercontent.com/$OWNER/$REPO/master/khrej_config.json"
    local dest_file="config.json"

    echo "Downloading config.json from $github_url..."
    wget -q -O "$dest_file" "$github_url"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to download config.json."
      return 1
    fi
    read -p "Enter Iran IPv4: " iran_ip
    read -p "Please enter your Sni. (It is better to use internal sites with ir domain): " sni
    read -p "Enter your MUX concurrency (For a large number of users, a larger number should be used, such as 128 and 256): " concurrency

    echo "Iran IP: $iran_ip"
    echo "sni: $sni"
    echo "Mux concurrency: $concurrency"


    jq --arg sni "$sni" '.nodes[] | select(.name == "reality_client") .settings.sni = $sni' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update SNI in reality_client."
      return 1
    fi

    jq --arg sni "$sni" '.nodes[] | select(.name == "h2client") .settings.host = $sni' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update SNI in h2client."
      return 1
    fi

    jq --arg address "$iran_ip" '.nodes[] | select(.name == "outbound_to_iran") .settings.address = $address' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update address in outbound_to_iran."
      return 1
    fi

    jq --argjson concurrency "$concurrency" '.nodes[] | select(.name == "h2client") .settings.concurrency = $concurrency' "$dest_file" > temp.json && mv temp.json "$dest_file"
    if [ $? -ne 0 ]; then
      echo "Error: Unable to update concurrency in h2client."
      return 1
    fi

    echo "config.json updated successfully."

    read -p "Press enter to continue..."
    main_menu
    

}

setup_waterwall_service() {
    cat > /etc/systemd/system/waterwall.service << EOF
[Unit]
Description=Waterwall Service
After=network.target

[Service]
ExecStart=/root/RRT/Waterwall
WorkingDirectory=/root/RRT
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable waterwall
    systemctl start waterwall
}

# Function to display the logo
function display_logo {
    echo " _  _   __  ____  ____  ____  _  _   __   __    __    _   "
    echo "/ )( \ / _\(_  _)(  __)(  _ \/ )( \ / _\ (  )  (  )  / \  "
    echo "\ /\ //    \ )(   ) _)  )   /\ /\ //    \/ (_/\/ (_/\\_/  "
    echo "(_/\_)\_/\_/(__) (____)(__\_)(_/\_)\_/\_/\____/\____/(_)  "
}

# Start the script
main_menu
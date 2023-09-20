#!/bin/ash

# Function to run a command, suppressing stdout but displaying stderr
run_command() {
  "$@" > /dev/null 2>&1
}

# Function to create a tar archive as a string
create_tar_string() {
  if [ -f "$1" ]; then
    tar -czf - -C "$2" "$(basename "$1")" | base64
  fi
}

# Function to decode and extract a tar-encoded string to a directory
decode_tar_string() {
  if [ -n "$1" ] && [ -n "$2" ]; then
    echo "$1" | base64 -d | tar -xz -C "$2"
  fi
}

# Function to extract TunnelID from JSON content
extract_tunnel_id() {
  if [ -n "$1" ]; then
    tunnel_id=$(echo "$1" | awk -F'"TunnelID":' '{print $2}' | tr -d '", }')
    echo "$tunnel_id"
  fi
}

# Create necessary directories
echo "Creating directories..."
mkdir -p /tmp/cloudflared/root/.cloudflared
mkdir -p /tmp/cloudflared/proc
mkdir -p /tmp/cloudflared/etc/ssl
cp -r /etc/ssl /tmp/cloudflared/etc/
echo "Directories created."
echo ""

# Update package list
echo "Updating package list..."
run_command opkg update
echo "Package list updated."
echo ""

# Check if coreutils-base64 is installed
if ! opkg list-installed coreutils-base64 > /dev/null 2>&1; then
  echo "Installing coreutils-base64..."
  run_command opkg install coreutils-base64
  echo "coreutils-base64 installed."
  echo ""
fi

# Get the filename of the downloaded package
filename=$(opkg info cloudflared | awk -F ": " '/Filename:/ {print $2}')

# Navigate to the cloudflared directory
cd /tmp/cloudflared

# Download and extract the cloudflared package
echo "Downloading and extracting cloudflared package..."
run_command opkg download cloudflared
run_command tar zxpvf "$filename"
rm "$filename"
rm debian-binary control.tar.gz
echo "Cloudflared package downloaded and extracted."
echo ""

# Extract the package's data
echo "Extracting package data..."
run_command tar zxpvf data.tar.gz
rm data.tar.gz
echo "Package data extracted."
echo ""

# Remove the default config file
echo "Removing default config file..."
run_command rm /tmp/cloudflared/etc/cloudflared/config.yml
echo "Default config file removed."
echo ""

# Mount the proc filesystem
echo "Mounting proc filesystem..."
run_command mount -t proc proc /tmp/cloudflared/proc
echo "Proc filesystem mounted."
echo ""

# Copy dependencies to their respective folders
echo "Copying dependencies of cloudflared..."
deps=$(ldd /tmp/cloudflared/usr/bin/cloudflared | awk '/=>/ {print $3}')
for dep in $deps; do
  dep_filename=$(basename "$dep")
  dep_dirname=$(dirname "$dep")
  mkdir -p "/tmp/cloudflared$dep_dirname"
  run_command cp "$dep" "/tmp/cloudflared$dep_dirname/$dep_filename"
done
echo "All dependencies copied to their respective folders in /tmp/cloudflared."
echo ""

# Check if two parameters are provided for decryption
if [ $# -eq 2 ]; then
  echo "Decoding and extracting cert.pem..."
  decode_tar_string "$1" /tmp/cloudflared/root/.cloudflared/cert.pem
  echo "cert.pem content decoded and extracted."
  echo ""

  echo "Decoding and extracting JSON content..."
  decode_tar_string "$2" /tmp/cloudflared/root/.cloudflared/temp.json
  echo ""
  
  # Extract the TunnelID from the JSON file to determine its name
  tunnel_id=$(extract_tunnel_id "$(cat /tmp/cloudflared/root/.cloudflared/temp.json)")

  # Rename the JSON file with the TunnelID
  if [ -n "$tunnel_id" ]; then
    mv "/tmp/cloudflared/root/.cloudflared/temp.json" "/tmp/cloudflared/root/.cloudflared/$tunnel_id.json"
  fi

  echo "JSON content decoded and extracted."
  echo ""
else
  # Execute chroot and echo success
  echo "Starting cloudflared tunnel login..."
  chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel login
  echo "Login process finished."
  echo ""

  # Create tunnel
  echo "Creating cloudflared tunnel..."
  run_command chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel create openwrt
  echo "Tunnel created."
  echo ""

  # Create a tar archive as a string for later use
  cert_tar_string=$(create_tar_string /tmp/cloudflared/root/.cloudflared/cert.pem /tmp/cloudflared/root/.cloudflared)
  json_tar_string=$(create_tar_string /tmp/cloudflared/root/.cloudflared/*.json /tmp/cloudflared/root/.cloudflared)

  # Print the command for future execution
  echo "To start this Tunnel next time (or to execute after bootup), use:"
  echo "./script.sh \"$cert_tar_string\" \"$json_tar_string\""
  echo ""
fi

echo "Starting cloudflared tunnel \"openwrt\"..."
chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel run openwrt > /dev/null 2>&1 &
echo "Your tunnel is up and running. Configure your tunnel in dashboard to add public hostnames."

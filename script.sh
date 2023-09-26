#!/bin/ash

# Function to run a command, suppressing stdout but displaying stderr
run_command() {
  "$@" > /dev/null 2>&1
}

# Function to create a tar archive as a string
create_tar_string() {
  if [ -f "$1" ] || [ -d "$1" ]; then
    tar -czf - -C "$(dirname "$1")" "$(basename "$1")" | base64 | tr -d '\n'
  fi
}

# Function to decode and extract a tar-encoded string to a directory
decode_tar_string() {
  if [ -n "$1" ] && [ -n "$2" ]; then
    echo "$1" | base64 -d | tar -xz -C "$2"
  fi
}

# Function to display script usage
display_usage() {
  echo "Usage: $0 [--import=<base64_string>] [-l] [--help]"
  echo "Options:"
  echo "  -l                         Start with Cloudflare login (Domain + Account required)"
  echo "  --import=<base64_string>   Import a Cloudflared config from a base64 string"
  echo "  --help                     Display this help message"
}

# Initialize variables
login=false
import_string=""
tunnel_url="http://localhost:8080"  # Default tunnel URL

# Parse command-line arguments
for arg in "$@"; do
  case "$arg" in
    --import=*)
      import_string="${arg#*=}"
      ;;
    -l)
      login=true
      ;;
    --url=*)
      tunnel_url="${arg#*=}"
      ;;
    --help)
      display_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      display_usage
      exit 1
      ;;
  esac
done

# Create necessary directories
echo "Creating directories..."
mkdir -p /tmp/cloudflared/root
mkdir -p /tmp/cloudflared/proc
mkdir -p /tmp/cloudflared/sys
mkdir -p /tmp/cloudflared/dev
mkdir -p /tmp/cloudflared/etc/ssl
cp -r /etc/ssl /tmp/cloudflared/etc/
cp /etc/resolv.conf /tmp/cloudflared/etc/resolv.conf
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
echo "Mounting proc, dev and sys filesystem..."
run_command mount -t proc proc /tmp/cloudflared/proc
run_command mount -t sysfs none /tmp/cloudflared/sys
run_command mount --bind /dev /tmp/cloudflared/dev
echo "Proc, dev and sys filesystems mounted."
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

# Check if login is set to false and tunnel_url is not empty
if [ "$login" = false ]; then
  echo "Starting Quick Tunnel for URL: $tunnel_url"
  echo ""

  # Start cloudflared and redirect its output to the log file
  chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel --url "$tunnel_url" > /tmp/cloudflared/cloudflared.log 2>&1 &

  # Give the process a moment to start and populate the logfile
  sleep 2

  # Monitor the log file and search for the URL
  tail -f /tmp/cloudflared/cloudflared.log | while read -r LINE; do
      url=$(echo "$LINE" | grep -oE 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com' | head -n 1)
      if [ ! -z "$url" ]; then
          echo "Your tunnel is up and running! URL: $url"
          break
      fi
  done

  # Detach and let processes run
  exit 0
fi

# Check if --import parameter is provided for decryption
if [ -n "$import_string" ]; then
  echo "Restoring /root/.cloudflared..."
  decode_tar_string "$import_string" "/tmp/cloudflared/root/"
  echo "/root/.cloudflared restored."
  echo ""
else
  # Execute chroot
  echo "Starting cloudflared tunnel login..."
  chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel login
  echo "Login finished."
  echo ""

  # Create tunnel
  echo "Creating cloudflared tunnel..."
  run_command chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel create openwrt
  echo "Tunnel created."
  echo ""

  # Create a tar archive as a string for later use
  tar_string=$(create_tar_string /tmp/cloudflared/root/.cloudflared/)

  # Print the command for future execution
  echo "To start this Tunnel next time (or to execute after bootup), run:"
  echo "wget -qO- https://raw.githubusercontent.com/adshrc/openwrt-cloudflared/main/script.sh | ash -s -- --import=\"$tar_string\""
  echo ""
fi

echo "Starting cloudflared tunnel \"openwrt\"..."
chroot /tmp/cloudflared/ /usr/bin/cloudflared tunnel run openwrt > /dev/null 2>&1 &
echo "Your tunnel is up and running. Configure your tunnel in dashboard to add public hostnames."

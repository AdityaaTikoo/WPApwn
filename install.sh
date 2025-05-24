if [[ $EUID -ne 0 ]]; then
  echo "Please run this installer as root !"
  exit 1
fi

echo "Updating and upgrading package list..."
apt update -y && apt upgrade -y

echo "Installing dependencies..."

apt install aircrack-ng iproute2 xterm wordlists wireless-tools -y

exit 0


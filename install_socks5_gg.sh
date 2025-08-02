#!/bin/bash

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[*] Updating package list...${NC}"
sudo apt update

echo -e "${GREEN}[*] Installing microsocks...${NC}"
sudo apt install -y microsocks

echo -e "${GREEN}[*] Creating systemd service...${NC}"
cat <<EOF | sudo tee /etc/systemd/system/microsocks.service > /dev/null
[Unit]
Description=microsocks SOCKS5 server
Documentation=https://github.com/rofl0r/microsocks
After=network.target auditd.service

[Service]
EnvironmentFile=/etc/microsocks.conf
ExecStart=/usr/bin/microsocks -u \${MICROSOCKS_LOGIN} -P \${MICROSOCKS_PASSW}

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}[*] Creating config file...${NC}"
cat <<EOF | sudo tee /etc/microsocks.conf > /dev/null
# used by the systemd service file
MICROSOCKS_LOGIN="aXyinxF"
MICROSOCKS_PASSW="C6gTuHLP"
EOF

echo -e "${GREEN}[*] Allowing port 88888...${NC}"
sudo ufw allow 88888/tcp || true

echo -e "${GREEN}[*] Enabling and starting microsocks service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable microsocks
sudo systemctl start microsocks

echo -e "${GREEN}[✔] Microsocks installation complete!${NC}"
sudo systemctl status microsocks --no-pager

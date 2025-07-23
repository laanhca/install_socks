#!/usr/bin/env bash
# SOCKS5 (Dante) auto installer for Ubuntu/Debian/RedHat

set -e

# Function to draw box around text
draw_box() {
    local title="$1"
    local content="$2"
    local width=60

    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color
    local BOLD='\033[1m'

    echo -e "${GREEN}┌$(printf '─%.0s' $(seq 1 $((width-2))))┐${NC}"
    echo -e "${GREEN}│${BOLD}${YELLOW} $(printf "%-*s" $((width-4)) "$title") ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}├$(printf '─%.0s' $(seq 1 $((width-2))))┤${NC}"

    while IFS= read -r line; do
        echo -e "${GREEN}│${NC} $(printf "%-*s" $((width-4)) "$line") ${GREEN}│${NC}"
    done <<< "$content"

    echo -e "${GREEN}└$(printf '─%.0s' $(seq 1 $((width-2))))┘${NC}"
}

# Detect OS
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) OS="debian" ;;
        amzn|centos|rhel|rocky|almalinux) OS="redhat" ;;
        *) echo "❌ Unsupported OS: $ID"; exit 1 ;;
    esac
else
    echo "❌ Cannot detect OS."; exit 1
fi

# Common variables
EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
EXT_IF=${EXT_IF:-eth0}
PUBLIC_IP=$(curl -4 -s https://api.ipify.org)

USERNAME="user_for_socks5"
PASSWORD="strongPassword123"
PORT=20326

# Install packages
if [ "$OS" = "debian" ]; then
    apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y dante-server curl iptables iptables-persistent jq >/dev/null 2>&1
else
    yum install -y epel-release >/dev/null 2>&1
    yum install -y dante-server curl iptables-services jq >/dev/null 2>&1
    systemctl enable iptables >/dev/null 2>&1
    systemctl start iptables >/dev/null 2>&1
fi

useradd -M -N -s /usr/sbin/nologin "$USERNAME" >/dev/null 2>&1 || true
echo "${USERNAME}:${PASSWORD}" | chpasswd >/dev/null 2>&1

cat > /etc/danted.conf <<EOF
logoutput: syslog /var/log/danted.log
internal: 0.0.0.0 port = ${PORT}
external: ${EXT_IF}

method: pam
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
EOF

chmod 644 /etc/danted.conf
systemctl restart danted >/dev/null 2>&1
systemctl enable danted >/dev/null 2>&1

# Open firewall
if command -v ufw >/dev/null 2>&1; then
    ufw allow "${PORT}/tcp" >/dev/null 2>&1
else
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1
    iptables-save > /etc/iptables/rules.v4 >/dev/null 2>&1 || true
fi

# Output JSON result
cat <<EOF > /root/proxy_info.json
{
  "ip": "${PUBLIC_IP}",
  "port": "${PORT}",
  "username": "${USERNAME}",
  "password": "${PASSWORD}",
  "proxy": "socks5://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"
}
EOF

draw_box "🧦 SOCKS5 PROXY INSTALLED" "socks5://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"

#!/usr/bin/env bash
# HTTP (Squid) proxy auto installer for Ubuntu/Debian/RedHat with basic auth

set -e

# Function to draw box
draw_box() {
    local title="$1"
    local content="$2"
    local width=60

    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m'
    local BOLD='\033[1m'

    echo ""
    echo -e "${GREEN}┌$(printf '─%.0s' $(seq 1 $((width-2))))┐${NC}"
    echo -e "${GREEN}│${BOLD}${YELLOW} $(printf "%-*s" $((width-4)) "$title") ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}├$(printf '─%.0s' $(seq 1 $((width-2))))┤${NC}"
    while IFS= read -r line; do
        echo -e "${GREEN}│${NC} $(printf "%-*s" $((width-4)) "$line") ${GREEN}│${NC}"
    done <<< "$content"
    echo -e "${GREEN}└$(printf '─%.0s' $(seq 1 $((width-2))))┘${NC}"
    echo ""
}

# Detect OS
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) OS="debian" ;;
        *) echo "❌ Unsupported OS: $ID"; exit 1 ;;
    esac
else
    echo "❌ Cannot detect OS."; exit 1
fi

# Detect external IP
EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
EXT_IF=${EXT_IF:-eth0}
PUBLIC_IP=$(curl -4 -s --max-time 5 https://api.ipify.org || echo "IP_NOT_FOUND")

USERNAME="user_for_http"
PASSWORD="strongPassword123"
PORT=20327

echo "[*] Installing Squid HTTP proxy on $OS..."

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y squid apache2-utils curl ufw

mkdir -p /etc/squid

# Create user auth
htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

# Backup config
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.$(date +%F_%T) || true

# Generate minimal squid config with auth
cat > /etc/squid/squid.conf <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Squid Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

http_port ${PORT}
visible_hostname proxy-server

cache deny all
EOF

chmod 644 /etc/squid/squid.conf

systemctl restart squid
systemctl enable squid

# --- UFW firewall setup ---
echo "[*] Configuring UFW firewall..."

# Ensure SSH is allowed to prevent lockout
ufw allow ssh || true

# Allow proxy port
ufw allow "${PORT}/tcp" || true

# Enable ufw if not active
if ! ufw status | grep -q "Status: active"; then
    echo "[*] Enabling UFW..."
    ufw --force enable
fi

# Output proxy string
PROXY_URL="${PUBLIC_IP}:${PORT}:${USERNAME}:${PASSWORD}"

# Export JSON for automation
cat <<EOF > /root/proxy_info.json
{
  "ip": "${PUBLIC_IP}",
  "port": "${PORT}",
  "username": "${USERNAME}",
  "password": "${PASSWORD}",
  "proxy": "${PROXY_URL}"
}
EOF

draw_box "🌐 HTTP PROXY SERVER" "$PROXY_URL"

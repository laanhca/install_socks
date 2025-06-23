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
        amzn|centos|rhel|rocky|almalinux) OS="redhat" ;;
        *) echo "❌ Unsupported OS: $ID"; exit 1 ;;
    esac
else
    echo "❌ Cannot detect OS."; exit 1
fi

# Detect external interface and IP
EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
EXT_IF=${EXT_IF:-eth0}
PUBLIC_IP=$(curl -4 -s --max-time 5 https://api.ipify.org || echo "IP_NOT_FOUND")

install_http_proxy() {
    local USERNAME="user_for_socks5"
    local PASSWORD="t9X@rP2#Vm8wZ!dLq7&E"
    local PORT=20326

    echo "[*] Cài đặt Squid proxy cho hệ điều hành: $OS..."

    if [ "$OS" = "debian" ]; then
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y squid apache2-utils curl iptables iptables-persistent
    else
        yum install -y squid httpd-tools curl iptables-services
        systemctl enable iptables
        systemctl start iptables
    fi

    # Ensure Squid config folder exists
    mkdir -p /etc/squid

    # Setup basic auth
    htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

    # Backup config
    cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.$(date +%F_%T) || true

    # Create new config
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

    # Restart squid
    systemctl restart squid
    systemctl enable squid

    # Open firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${PORT}/tcp" || true
    else
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT || true
        iptables-save > /etc/iptables/rules.v4 || true
    fi

    echo "http://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"
}

echo "🚀 Đang cài đặt HTTP proxy (Squid) với xác thực cơ bản..."
proxy_info=$(install_http_proxy)
draw_box "🌐 HTTP PROXY SERVER" "$proxy_info"

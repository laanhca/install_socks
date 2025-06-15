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

EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
EXT_IF=${EXT_IF:-eth0}
PUBLIC_IP=$(curl -4 -s https://api.ipify.org)

install_http_proxy() {
    local USERNAME PASSWORD PORT
    USERNAME="user_$(tr -dc 'a-z0-9' </dev/urandom | head -c8)"
    PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"
    PORT=$(shuf -i 3129-65000 -n1)

    if [ "$OS" = "debian" ]; then
        apt-get update >/dev/null 2>&1
        apt-get install -y squid apache2-utils curl iptables iptables-persistent >/dev/null 2>&1
    else
        yum install -y squid httpd-tools curl iptables-services >/dev/null 2>&1
        systemctl enable iptables >/dev/null 2>&1
        systemctl start iptables >/dev/null 2>&1
    fi

    # Setup auth
    htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD" >/dev/null 2>&1

    # Backup config
    cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.$(date +%F_%T) >/dev/null 2>&1

    # Minimal Squid config with auth
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
    systemctl restart squid >/dev/null 2>&1
    systemctl enable squid >/dev/null 2>&1

    # Firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${PORT}/tcp" >/dev/null 2>&1
    else
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1
        iptables-save > /etc/iptables/rules.v4 >/dev/null 2>&1 || true
    fi

    # Return proxy info
    echo "http://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"
}

echo "🚀 Installing HTTP proxy (Squid) with basic authentication..."
proxy_info=$(install_http_proxy)
draw_box "🌐 HTTP PROXY SERVER" "$proxy_info"

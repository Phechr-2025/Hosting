#!/bin/bash
# ============================================================
#  Web Hosting Installer - One Command Setup
#  Supports: Ubuntu | Debian | CentOS | Rocky | Fedora | Arch
#  Version: 1.0.0
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ---------- Utilities ----------
clear_screen() {
    clear
}

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}              WEB HOSTING INSTALLER v1.0.0                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${DIM}         One-Command Setup | Auto SSL | Nginx               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_cyan()    { echo -e "${CYAN}$1${NC}"; }

# ---------- Progress Bar ----------
show_progress() {
    local label="$1"
    local percent=$2
    local width=40
    local filled=$(( width * percent / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo -e "\r${label}"
    echo -e "[${CYAN}${bar}${NC}] ${percent}%"
}

# ---------- Check Root ----------
check_root() {
    echo -e "${BOLD}Checking administrator permission...${NC}"
    sleep 0.5
    if [[ $EUID -ne 0 ]]; then
        print_error "Administrator permission required"
        echo ""
        echo -e "${YELLOW}Linux:${NC} ${BOLD}sudo bash install.sh${NC}"
        echo -e "${YELLOW}Windows:${NC} ${BOLD}Run PowerShell as Administrator${NC}"
        echo ""
        exit 1
    fi
    print_success "Root/Administrator detected"
    echo ""
}

# ---------- Detect OS ----------
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi

    case "$OS" in
        ubuntu|debian)     OS_TYPE="debian" ;;
        centos|rhel)       OS_TYPE="rhel"   ;;
        rocky|almalinux)   OS_TYPE="rhel"   ;;
        fedora)            OS_TYPE="fedora" ;;
        arch|manjaro)      OS_TYPE="arch"   ;;
        *)                 OS_TYPE="unknown" ;;
    esac

    print_info "Detected OS: ${BOLD}${OS} ${VER}${NC}"
    echo ""
}

# ---------- Package Manager ----------
get_pkg_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_pkg() {
    local pkg=$1
    local pm=$(get_pkg_manager)
    case $pm in
        apt)     apt-get install -y -qq "$pkg" &> /dev/null ;;
        dnf)     dnf install -y -q "$pkg" &> /dev/null ;;
        yum)     yum install -y -q "$pkg" &> /dev/null ;;
        pacman)  pacman -S --noconfirm --quiet "$pkg" &> /dev/null ;;
    esac
}

# ---------- Install Dependencies ----------
step_install_deps() {
    echo -e "${BOLD}Installing required packages...${NC}"

    local pm=$(get_pkg_manager)
    local pkgs=("nginx" "certbot" "curl" "bind9-host" "dnsutils" "openssl")

    if [[ "$pm" == "apt" ]]; then
        apt-get update -qq &> /dev/null
        pkgs=("nginx" "certbot" "python3-certbot-nginx" "curl" "dnsutils" "openssl")
    elif [[ "$pm" == "dnf" || "$pm" == "yum" ]]; then
        pkgs=("nginx" "certbot" "python3-certbot-nginx" "curl" "bind-utils" "openssl")
    elif [[ "$pm" == "pacman" ]]; then
        pkgs=("nginx" "certbot" "curl" "bind" "openssl")
    fi

    local total=${#pkgs[@]}
    for ((i=0; i<total; i++)); do
        local pct=$(( i * 35 / total ))
        show_progress "Installing required packages..." $pct
        echo -e "  ${DIM}→ Installing ${pkgs[$i]}...${NC}"
        install_pkg "${pkgs[$i]}"
        sleep 0.2
    done

    show_progress "Installing required packages..." 35
    echo ""
}

# ---------- Install Web Server ----------
step_install_nginx() {
    echo -e "${BOLD}Installing web server...${NC}"

    systemctl enable nginx &> /dev/null
    systemctl start nginx &> /dev/null

    show_progress "Installing web server..." 70
    echo ""
    print_success "Nginx installed and started"
    echo ""
}

# ---------- Get IPs ----------
get_public_ip() {
    local ip
    ip=$(curl -s -m 5 https://api.ipify.org 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

# ---------- Domain Validation ----------
check_domain_dns() {
    local domain=$1
    local vps_ip=$2

    local resolved
    resolved=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)

    if [[ -z "$resolved" ]]; then
        resolved=$(dig +short "$domain" 2>/dev/null | head -n1)
    fi

    if [[ -z "$resolved" ]]; then
        resolved=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1)
    fi

    if [[ "$resolved" == "$vps_ip" ]]; then
        echo "match"
    else
        echo "nomatch"
    fi
}

# ---------- Cloudflare Check ----------
check_cloudflare_ns() {
    local domain=$1
    local ns
    ns=$(dig +short NS "$domain" 2>/dev/null | head -n1)
    if echo "$ns" | grep -qi "cloudflare"; then
        echo "yes"
    else
        echo "no"
    fi
}

check_cf_proxy() {
    local domain=$1
    local headers
    headers=$(curl -sI -m 5 "http://$domain" 2>/dev/null | grep -i "cf-ray\|cloudflare" | head -n1)
    if [[ -n "$headers" ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# ---------- Port Check ----------
is_port_reserved() {
    local port=$1
    local reserved=(22 25 53 80 110 143 443 465 587 993 995 3306 5432 6379 27017 8080 8443)
    for p in "${reserved[@]}"; do
        if [[ "$port" == "$p" ]]; then
            echo "yes"
            return
        fi
    done
    echo "no"
}

is_port_in_use() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        echo "yes"
    else
        echo "no"
    fi
}

# ---------- SSL Config ----------
generate_nginx_conf() {
    local domain=$1
    local port=$2
    local ssl_type=$3
    local cf_mode=$4

    local conf_dir="/etc/nginx/sites-available"
    local webroot="/var/www/${domain}"

    mkdir -p "$webroot"

    if [[ "$ssl_type" == "1" ]]; then
        # Let's Encrypt
        cat > "${conf_dir}/${domain}" <<EOF
server {
    listen 80;
    server_name ${domain};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen ${port} ssl http2;
    server_name ${domain};

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;

    root ${webroot};
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

        mkdir -p /var/www/certbot

    elif [[ "$ssl_type" == "2" ]]; then
        # Cloudflare
        cat > "${conf_dir}/${domain}" <<EOF
server {
    listen ${port};
    server_name ${domain};

    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    real_ip_header CF-Connecting-IP;

    root ${webroot};
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    else
        # HTTP Only
        cat > "${conf_dir}/${domain}" <<EOF
server {
    listen ${port};
    server_name ${domain};

    root ${webroot};
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    fi

    # Enable site
    ln -sf "${conf_dir}/${domain}" "/etc/nginx/sites-enabled/${domain}"

    # Test and reload
    nginx -t &> /dev/null && systemctl reload nginx &> /dev/null
}

# ---------- Create Index Page ----------
create_index() {
    local domain=$1
    local ssl_type=$2
    local webroot="/var/www/${domain}"

    local ssl_text="HTTP Only"
    [[ "$ssl_type" == "1" ]] && ssl_text="Let's Encrypt"
    [[ "$ssl_type" == "2" ]] && ssl_text="Cloudflare SSL"

    cat > "${webroot}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to ${domain}</title>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255,255,255,0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.2);
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .success { color: #00ff88; font-weight: bold; }
        .info { margin-top: 20px; opacity: 0.9; }
        .badge {
            display: inline-block;
            padding: 8px 16px;
            background: rgba(255,255,255,0.2);
            border-radius: 20px;
            margin-top: 15px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Welcome to <span class="success">${domain}</span></h1>
        <p>Your web hosting has been successfully configured!</p>
        <div class="badge">SSL: ${ssl_text}</div>
        <div class="info">
            <p>Powered by Web Hosting Installer</p>
            <p style="font-size: 0.8em; margin-top: 10px;">Type <b>hosting</b> in terminal to manage</p>
        </div>
    </div>
</body>
</html>
EOF

    chown -R www-data:www-data "$webroot" 2>/dev/null || true
}

# ---------- Setup Auto Renew ----------
setup_auto_renew() {
    local domain=$1
    local email=$2

    # Let's Encrypt auto renew via cron
    (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 0,12 * * * python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q") | crontab -

    # Get certificate
    local email_arg=""
    [[ -n "$email" && "$email" != "n" ]] && email_arg="--email $email" || email_arg="--register-unsafely-without-email"

    certbot certonly --webroot -w /var/www/certbot -d "$domain" $email_arg --agree-tos -n &> /dev/null

    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate obtained successfully"
    else
        print_warn "SSL certificate failed, continuing with HTTP"
    fi
}

# ---------- Install Hosting Command ----------
install_hosting_cmd() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    cat > /usr/local/bin/hosting <<'MENU_EOF'
#!/bin/bash
# ============================================================
#  Web Hosting Management Menu
#  Run: hosting
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CONFIG_FILE="/etc/hosting-config.json"

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}              WEB HOSTING MANAGEMENT MENU                     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }

show_status() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}⚠️  No configuration found. Run installer first.${NC}"
        echo ""
        return
    fi

    local domain=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    local port=$(grep -o '"port": [0-9]*' "$CONFIG_FILE" | cut -d' ' -f2)
    local ssl_type=$(grep -o '"ssl_type": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    local installed=$(grep -o '"installed_at": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

    local nginx_status="${RED}Stopped${NC}"
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx_status="${GREEN}Running${NC}"
    fi

    echo -e "${BLUE}┌─ Server Status ──────────────────────────────────────────────┐${NC}"
    echo -e "│  ${CYAN}Domain:${NC}    ${domain:-N/A}${NC}"
    echo -e "│  ${CYAN}Port:${NC}      ${port:-N/A}${NC}"
    echo -e "│  ${CYAN}SSL:${NC}       ${ssl_type:-HTTP Only}${NC}"
    echo -e "│  ${CYAN}Nginx:${NC}     ${nginx_status}${NC}"
    echo -e "│  ${CYAN}Installed:${NC} ${installed:-Unknown}${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

show_menu() {
    echo -e "${MAGENTA}┌─ Management Options ─────────────────────────────────────────┐${NC}"
    echo -e "│                                                            │"
    echo -e "│  ${YELLOW}[1]${NC} ${BOLD}Update System & Packages${NC}                             │"
    echo -e "│  ${YELLOW}[2]${NC} ${BOLD}Uninstall Hosting${NC}                                      │"
    echo -e "│                                                            │"
    echo -e "│  ${DIM}[3]${NC} ${DIM}View Logs${NC}                                            │"
    echo -e "│  ${DIM}[4]${NC} ${DIM}Restart Services${NC}                                     │"
    echo -e "│  ${DIM}[5]${NC} ${DIM}SSL Certificate Info${NC}                                 │"
    echo -e "│                                                            │"
    echo -e "│  ${RED}[0]${NC} Exit                                                 │"
    echo -e "│                                                            │"
    echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

do_update() {
    clear
    print_header
    echo -e "${BOLD}Update System & Packages${NC}"
    echo "──────────────────────────────────────────────────────────────"
    echo ""

    if command -v apt-get &> /dev/null; then
        print_info "Updating package lists..."
        apt-get update -qq
        print_info "Upgrading packages..."
        apt-get upgrade -y -qq
    elif command -v dnf &> /dev/null; then
        print_info "Updating packages..."
        dnf update -y -q
    elif command -v yum &> /dev/null; then
        print_info "Updating packages..."
        yum update -y -q
    fi

    print_info "Updating certbot..."
    pip3 install --upgrade certbot certbot-nginx &> /dev/null || true

    print_info "Restarting nginx..."
    systemctl restart nginx

    echo ""
    print_success "Update completed successfully!"
    echo ""
    read -p "Press Enter to continue..."
}

do_uninstall() {
    clear
    print_header
    echo -e "${RED}${BOLD}⚠️  UNINSTALL HOSTING${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${RED}WARNING:${NC} This will remove ALL hosting configurations!"
    echo ""
    echo "The following will be deleted:"
    echo "  • Nginx configuration for your domain"
    echo "  • Web root directory (/var/www/<domain>)"
    echo "  • SSL certificates (if Let's Encrypt)"
    echo "  • Hosting configuration file"
    echo ""

    read -p "Type 'UNINSTALL' to confirm: " confirm

    if [[ "$confirm" != "UNINSTALL" ]]; then
        print_warn "Uninstall cancelled."
        sleep 1
        return
    fi

    echo ""
    print_info "Starting uninstallation..."

    if [[ -f "$CONFIG_FILE" ]]; then
        local domain=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

        if [[ -n "$domain" ]]; then
            rm -f "/etc/nginx/sites-enabled/${domain}"
            rm -f "/etc/nginx/sites-available/${domain}"
            rm -rf "/var/www/${domain}"
            rm -rf "/etc/letsencrypt/live/${domain}"
        fi
    fi

    nginx -t &> /dev/null && systemctl reload nginx &> /dev/null

    rm -f "$CONFIG_FILE"
    rm -f /usr/local/bin/hosting

    echo ""
    print_success "Uninstallation completed!"
    echo ""
    echo -e "${CYAN}Thank you for using Web Hosting Installer!${NC}"
    echo ""
    exit 0
}

view_logs() {
    clear
    print_header
    echo -e "${BOLD}View Logs${NC}"
    echo "──────────────────────────────────────────────────────────────"
    echo ""

    echo -e "${BLUE}Nginx Error Log (last 50 lines):${NC}"
    echo "──────────────────────────────────────────────────────────────"
    tail -n 50 /var/log/nginx/error.log 2>/dev/null || echo "No error log found"
    echo ""

    echo -e "${BLUE}Nginx Access Log (last 20 lines):${NC}"
    echo "──────────────────────────────────────────────────────────────"
    tail -n 20 /var/log/nginx/access.log 2>/dev/null || echo "No access log found"
    echo ""

    read -p "Press Enter to continue..."
}

restart_services() {
    clear
    print_header
    echo -e "${BOLD}Restart Services${NC}"
    echo "──────────────────────────────────────────────────────────────"
    echo ""

    print_info "Restarting nginx..."
    if systemctl restart nginx; then
        print_success "Nginx restarted successfully!"
    else
        print_error "Failed to restart nginx"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

ssl_info() {
    clear
    print_header
    echo -e "${BOLD}SSL Certificate Info${NC}"
    echo "──────────────────────────────────────────────────────────────"
    echo ""

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warn "No configuration found."
        read -p "Press Enter to continue..."
        return
    fi

    local domain=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    local ssl_type=$(grep -o '"ssl_type": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

    echo -e "${CYAN}Domain:${NC} ${domain:-N/A}"
    echo -e "${CYAN}SSL Type:${NC} ${ssl_type:-HTTP Only}"
    echo ""

    if [[ "$ssl_type" == "letsencrypt" ]]; then
        local cert="/etc/letsencrypt/live/${domain}/cert.pem"
        if [[ -f "$cert" ]]; then
            echo -e "${BLUE}Certificate details:${NC}"
            openssl x509 -in "$cert" -noout -text 2>/dev/null | head -20
            echo ""
            echo -e "${BLUE}Expiry date:${NC}"
            openssl x509 -in "$cert" -noout -dates 2>/dev/null
        else
            print_warn "Certificate file not found."
        fi
    elif [[ "$ssl_type" == "cloudflare" ]]; then
        print_info "Cloudflare SSL is managed by Cloudflare dashboard."
        print_info "Visit: https://dash.cloudflare.com"
    else
        print_warn "HTTP Only - No SSL certificate."
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    print_header
    show_status
    show_menu

    read -p "Select option [0-5]: " choice

    case $choice in
        1) do_update ;;
        2) do_uninstall ;;
        3) view_logs ;;
        4) restart_services ;;
        5) ssl_info ;;
        0) 
            clear
            echo -e "${CYAN}Goodbye! 👋${NC}"
            echo ""
            exit 0
            ;;
        *) 
            print_error "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done
MENU_EOF

    chmod +x /usr/local/bin/hosting
    print_success "Installed 'hosting' command"
}

# ---------- Main Installation ----------
main() {
    clear_screen
    print_header
    check_root
    detect_os

    # Step 1: Install dependencies
    step_install_deps

    # Step 2: Install nginx
    step_install_nginx

    # Step 3: Domain
    echo -e "${BOLD}Domain Configuration${NC}"
    echo -e "${DIM}──────────────────────────────────────────────────────────────${NC}"
    echo ""

    local VPS_IP
    VPS_IP=$(get_public_ip)
    print_info "Your VPS IP: ${BOLD}${VPS_IP}${NC}"
    echo ""

    while true; do
        read -p "Enter your domain (pointed to this VPS): " domain
        domain=$(echo "$domain" | xargs)

        if [[ -z "$domain" ]]; then
            print_error "Domain cannot be empty"
            continue
        fi

        echo ""
        echo -e "Checking domain records for ${CYAN}${domain}${NC}..."
        sleep 1

        local dns_check
        dns_check=$(check_domain_dns "$domain" "$VPS_IP")

        if [[ "$dns_check" != "match" ]]; then
            print_error "Domain does not point to this VPS (${VPS_IP})"
            print_warn "Please check your DNS A Record and try again."
            echo ""
            read -p "Try again? (Y/n): " retry
            [[ "$retry" == "n" || "$retry" == "N" ]] && exit 1
            continue
        fi

        print_success "A Record verified: ${domain} → ${VPS_IP}"
        break
    done

    echo ""

    # Step 4: SSL Selection
    echo -e "${BOLD}SSL Configuration${NC}"
    echo -e "${DIM}──────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "1. Let's Encrypt (Auto Renew)"
    echo "2. Cloudflare SSL"
    echo "3. HTTP Only"
    echo ""

    while true; do
        read -p "Choose [1-3]: " ssl_choice
        if [[ "$ssl_choice" =~ ^[1-3]$ ]]; then
            break
        fi
        print_error "Invalid choice. Please enter 1, 2, or 3."
    done

    local ssl_type_name="http"
    local email=""
    local cf_mode=""
    local cf_security=""

    if [[ "$ssl_choice" == "1" ]]; then
        ssl_type_name="letsencrypt"
        echo ""
        echo -e "${BOLD}Enter Email for SSL Notification${NC}"
        echo "(Optional)"
        echo "Type 'n' to skip"
        read -p "> " email
        [[ "$email" == "n" || "$email" == "N" ]] && email=""

    elif [[ "$ssl_choice" == "2" ]]; then
        ssl_type_name="cloudflare"
        echo ""
        echo -e "Checking Cloudflare..."
        sleep 1

        local cf_ns
        cf_ns=$(check_cloudflare_ns "$domain")

        if [[ "$cf_ns" == "yes" ]]; then
            print_success "Cloudflare detected"
        else
            print_warn "Cloudflare not detected for this domain"
        fi

        local cf_proxy
        cf_proxy=$(check_cf_proxy "$domain")

        if [[ "$cf_proxy" == "yes" ]]; then
            print_success "Proxy is enabled"
        else
            print_error "Proxy is disabled"
            print_warn "Please enable Orange Cloud Proxy and try again."
            exit 1
        fi

        echo ""
        echo -e "${BOLD}Select Cloudflare SSL Mode${NC}"
        echo "1. Flexible"
        echo "2. Full"
        echo "3. Full (Strict) [Recommended]"
        echo "Default: 3"
        echo ""
        read -p "Choose [1-3]: " cf_choice
        cf_mode=${cf_choice:-3}

        echo ""
        echo -e "${BOLD}Enable Recommended Security?${NC}"
        echo "  - Always HTTPS"
        echo "  - HTTP/3"
        echo "  - Brotli Compression"
        echo "  - Security Headers"
        echo "Recommended: Yes"
        echo ""
        read -p "(Y/n): " sec_choice
        [[ "$sec_choice" == "n" || "$sec_choice" == "N" ]] && cf_security="no" || cf_security="yes"

        if [[ "$cf_security" == "yes" ]]; then
            print_info "Recommended security settings enabled"
        fi
    fi

    # Step 5: Port Selection
    echo ""
    echo -e "${BOLD}Select Web Port${NC}"
    echo -e "${DIM}──────────────────────────────────────────────────────────────${NC}"
    echo ""

    local default_port=443
    [[ "$ssl_choice" == "3" ]] && default_port=80

    echo "1. Default (${default_port})"
    echo "2. Custom Port"
    echo ""

    while true; do
        read -p "Choose [1-2]: " port_choice
        if [[ "$port_choice" =~ ^[1-2]$ ]]; then
            break
        fi
        print_error "Invalid choice"
    done

    local port=$default_port
    if [[ "$port_choice" == "2" ]]; then
        while true; do
            read -p "Enter custom port: " custom_port

            if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
                print_error "Invalid port number"
                continue
            fi

            local reserved
            reserved=$(is_port_reserved "$custom_port")
            if [[ "$reserved" == "yes" ]]; then
                print_error "Reserved/System Port"
                print_warn "Please choose another port"
                continue
            fi

            local in_use
            in_use=$(is_port_in_use "$custom_port")
            if [[ "$in_use" == "yes" ]]; then
                print_warn "Port ${custom_port} is in use, but continuing..."
            fi

            port=$custom_port
            break
        done
    fi

    echo ""
    echo -e "Checking port ${port}..."
    sleep 0.5
    print_success "Port available"
    echo ""

    # Step 6: Configure SSL
    echo -e "${BOLD}Configuring SSL...${NC}"
    generate_nginx_conf "$domain" "$port" "$ssl_choice" "$cf_mode"

    if [[ "$ssl_choice" == "1" ]]; then
        setup_auto_renew "$domain" "$email"
    fi

    show_progress "Configuring SSL..." 100
    echo ""

    # Step 7: Create index page
    create_index "$domain" "$ssl_choice"

    # Step 8: Save config
    cat > /etc/hosting-config.json <<EOF
{
  "domain": "${domain}",
  "port": ${port},
  "ssl_type": "${ssl_type_name}",
  "os_type": "${OS}",
  "email": "${email}",
  "cf_mode": "${cf_mode}",
  "cf_security": "${cf_security}",
  "installed_at": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

    # Step 9: Install hosting command
    install_hosting_cmd

    # Final
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}║           Installation Completed                             ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Domain:${NC}    ${BOLD}${domain}${NC}"
    echo -e "${CYAN}Port:${NC}      ${BOLD}${port}${NC}"
    echo -e "${CYAN}SSL:${NC}       ${BOLD}$([[ "$ssl_choice" == "1" ]] && echo "HTTPS (Let's Encrypt)" || [[ "$ssl_choice" == "2" ]] && echo "HTTPS (Cloudflare)" || echo "HTTP")${NC}"
    echo -e "${CYAN}Webroot:${NC}   ${BOLD}/var/www/${domain}${NC}"
    echo ""
    echo -e "${YELLOW}Type ${BOLD}hosting${NC} ${YELLOW}to open the management menu.${NC}"
    echo ""

    # Open firewall if ufw exists
    if command -v ufw &> /dev/null; then
        ufw allow "$port/tcp" &> /dev/null || true
        ufw allow 80/tcp &> /dev/null || true
    fi

    # Open firewall if firewalld exists
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port="${port}/tcp" &> /dev/null || true
        firewall-cmd --permanent --add-port=80/tcp &> /dev/null || true
        firewall-cmd --reload &> /dev/null || true
    fi
}

# Run main
main "$@"

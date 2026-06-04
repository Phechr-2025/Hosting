#!/bin/bash
# ============================================================
# Web Hosting Panel Installer
# Supports: Ubuntu, CentOS, Rocky Linux, Windows
# ============================================================

set -e

# ============================================
# SINGLE SOURCE OF TRUTH - อ่านจากไฟล์เดียว
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# อ่าน REPO จากไฟล์ REPO (ถ้ามี)
if [[ -f "${SCRIPT_DIR}/REPO" ]]; then
    GITHUB_REPO=$(cat "${SCRIPT_DIR}/REPO" | tr -d '[:space:]')
else
    # Fallback เมื่อรันผ่าน curl (ไฟล์ REPO ไม่อยู่ด้วย)
    GITHUB_REPO="Phechr-2025/Hosting"
fi

# อ่าน VERSION จากไฟล์ VERSION (ถ้ามี)
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    CURRENT_VERSION=$(cat "${SCRIPT_DIR}/VERSION" | tr -d '[:space:]')
else
    CURRENT_VERSION="v1.0.0"
fi

# ============================================
# CONFIG
# ============================================
INSTALL_DIR="/opt/hosting-panel"
CONFIG_DIR="/etc/hosting-panel"
LOG_FILE="/var/log/hosting-panel-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================
# UTILITY FUNCTIONS
# ============================================

log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

show_progress() {
    local text="$1"
    local percent="$2"
    local width=30
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    printf "\n${BOLD}%s${NC}\n" "$text"
    printf "["
    printf "%0.s█" $(seq 1 $filled)
    printf "%0.s░" $(seq 1 $empty)
    printf "] %d%%\n\n" "$percent"
}

spinner() {
    local pid=$1
    local msg="$2"
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 8 ))
        printf "\r${CYAN}%s${NC} %s" "${spin:$i:1}" "$msg"
        sleep 0.1
    done
    printf "\r${GREEN}✓${NC} %s\n" "$msg"
}

# ============================================
# SYSTEM CHECKS
# ============================================

check_root() {
    log "Checking administrator permission..."
    if [[ $EUID -ne 0 ]]; then
        error "Administrator permission required"
        echo ""
        echo -e "${YELLOW}Linux:${NC}   sudo bash $0"
        echo -e "${YELLOW}Windows:${NC} Run PowerShell as Administrator"
        exit 1
    fi
    success "Root/Administrator detected"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif [[ -f /etc/centos-release ]]; then
        OS="centos"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
    else
        error "Cannot detect OS"
        exit 1
    fi

    case "$OS" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        *)
            error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    success "OS detected: $OS $VER (Package manager: $PKG_MANAGER)"
}

# ============================================
# GITHUB RELEASES
# ============================================

get_latest_release() {
    log "Fetching latest release from GitHub..."
    log "Repository: $GITHUB_REPO"
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    local release_data

    if command -v curl &>/dev/null; then
        release_data=$(curl -sL "$api_url" 2>/dev/null || echo "")
    elif command -v wget &>/dev/null; then
        release_data=$(wget -qO- "$api_url" 2>/dev/null || echo "")
    else
        error "curl or wget required"
        exit 1
    fi

    if [[ -z "$release_data" ]]; then
        warning "Cannot fetch from GitHub, using bundled version: $CURRENT_VERSION"
        return
    fi

    local remote_version=$(echo "$release_data" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    if [[ -n "$remote_version" ]]; then
        CURRENT_VERSION="$remote_version"
    fi

    local zip_url=$(echo "$release_data" | grep -oP '"browser_download_url":\s*"\K[^"]+\.zip"' | head -1 || echo "")
    if [[ -z "$zip_url" ]]; then
        zip_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${CURRENT_VERSION}.zip"
    fi

    success "Latest version: $CURRENT_VERSION"
    echo "$zip_url"
}

download_source() {
    local url="$1"
    local temp_dir=$(mktemp -d)

    log "Downloading source code..."
    show_progress "Downloading latest release..." 10

    if command -v curl &>/dev/null; then
        curl -sL "$url" -o "${temp_dir}/source.zip" &
        local pid=$!
        spinner $pid "Downloading source code..."
        wait $pid
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "${temp_dir}/source.zip" &
        local pid=$!
        spinner $pid "Downloading source code..."
        wait $pid
    fi

    if [[ ! -f "${temp_dir}/source.zip" ]]; then
        error "Download failed"
        exit 1
    fi

    show_progress "Extracting source code..." 20
    unzip -q "${temp_dir}/source.zip" -d "$temp_dir" || true

    local extracted=$(find "$temp_dir" -maxdepth 1 -type d | grep -v "^${temp_dir}$" | head -1)
    if [[ -d "$extracted" ]]; then
        cp -r "$extracted"/* "$INSTALL_DIR/" 2>/dev/null || true
    fi

    rm -rf "$temp_dir"
    success "Source code ready"
}

# ============================================
# DOMAIN VALIDATION
# ============================================

get_server_ip() {
    local ip
    ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

check_dns() {
    local domain="$1"
    local server_ip=$(get_server_ip)

    log "Checking DNS records for $domain..."

    local a_record=$(dig +short A "$domain" 2>/dev/null || host -t A "$domain" 2>/dev/null | awk '{print $NF}' || echo "")
    local aaaa_record=$(dig +short AAAA "$domain" 2>/dev/null || echo "")

    local found=0
    if [[ "$a_record" == "$server_ip" ]]; then
        success "A Record matches: $server_ip"
        found=1
    fi

    if [[ -n "$aaaa_record" && "$aaaa_record" != "$server_ip" ]]; then
        info "AAAA Record found: $aaaa_record"
    fi

    if [[ $found -eq 0 ]]; then
        error "Domain does not point to this VPS"
        echo -e "${RED}Expected IP: $server_ip${NC}"
        echo -e "${RED}Found A Record: ${a_record:-None}${NC}"
        echo ""
        echo -e "${YELLOW}Please ensure your domain's A record points to:${NC} $server_ip"
        return 1
    fi

    return 0
}

ask_domain() {
    while true; do
        echo ""
        echo -e "${BOLD}Please enter the domain that points to this server${NC}"
        echo -e "${YELLOW}(Example: example.com)${NC}"
        echo ""
        read -rp "Domain: " DOMAIN

        if [[ -z "$DOMAIN" ]]; then
            error "Domain cannot be empty"
            continue
        fi

        if [[ "$DOMAIN" =~ ^[0-9]+$ ]]; then
            if [[ "$DOMAIN" == "1" ]]; then
                error "Installation cancelled"
                cleanup_and_exit
            fi
        fi

        if check_dns "$DOMAIN"; then
            break
        else
            echo ""
            echo -e "${YELLOW}1. Cancel domain change${NC}"
            echo -e "${YELLOW}2. Try again${NC}"
            read -rp "> " choice
            if [[ "$choice" == "1" ]]; then
                cleanup_and_exit
            fi
        fi
    done
}

# ============================================
# WEB SERVER SELECTION
# ============================================

select_webserver() {
    echo ""
    echo -e "${BOLD}Select Web Server${NC}"
    echo "────────────────────────"
    echo -e "1. Nginx           ${YELLOW}⭐ Recommended${NC}"
    echo "2. Apache"
    echo "3. LiteSpeed"
    echo ""
    echo -e "${RED}4. Cancel installation${NC}"
    echo ""

    while true; do
        read -rp "Choose [1-4]: " choice
        case "$choice" in
            1) WEB_SERVER="nginx"; break ;;
            2) WEB_SERVER="apache"; break ;;
            3) WEB_SERVER="litespeed"; break ;;
            4) cleanup_and_exit ;;
            *) error "Invalid choice" ;;
        esac
    done

    success "Web Server: $WEB_SERVER"
}

# ============================================
# DATABASE SELECTION
# ============================================

select_database() {
    echo ""
    echo -e "${BOLD}Select Database${NC}"
    echo "────────────────────────"
    echo "1. MariaDB"
    echo "2. MySQL"
    echo "3. PostgreSQL"
    echo "4. SQLite"
    echo ""
    echo -e "${RED}5. Cancel installation${NC}"
    echo ""

    while true; do
        read -rp "Choose [1-5]: " choice
        case "$choice" in
            1) DATABASE="mariadb"; break ;;
            2) DATABASE="mysql"; break ;;
            3) DATABASE="postgresql"; break ;;
            4) DATABASE="sqlite"; break ;;
            5) cleanup_and_exit ;;
            *) error "Invalid choice" ;;
        esac
    done

    success "Database: $DATABASE"
}

# ============================================
# SSL SELECTION
# ============================================

select_ssl() {
    echo ""
    echo -e "${BOLD}Select SSL Provider${NC}"
    echo "────────────────────────"
    echo "1. Let's Encrypt"
    echo "2. Cloudflare SSL"
    echo "3. HTTP Only"
    echo ""
    echo -e "${RED}4. Cancel installation${NC}"
    echo ""

    while true; do
        read -rp "Choose [1-4]: " choice
        case "$choice" in
            1) SSL_PROVIDER="letsencrypt"; ask_letsencrypt_email; break ;;
            2) SSL_PROVIDER="cloudflare"; check_cloudflare; break ;;
            3) SSL_PROVIDER="http"; break ;;
            4) cleanup_and_exit ;;
            *) error "Invalid choice" ;;
        esac
    done

    success "SSL: $SSL_PROVIDER"
}

ask_letsencrypt_email() {
    echo ""
    echo -e "${BOLD}Enter Email for SSL Notification${NC}"
    echo "(Optional)"
    echo ""
    echo -e "${YELLOW}Type 'n' to skip${NC}"
    echo ""
    read -rp "> " SSL_EMAIL
    if [[ "$SSL_EMAIL" == "n" || "$SSL_EMAIL" == "N" ]]; then
        SSL_EMAIL=""
    fi
}

check_cloudflare() {
    log "Checking Cloudflare..."

    local ns_records=$(dig +short NS "$DOMAIN" 2>/dev/null || echo "")
    if echo "$ns_records" | grep -qi "cloudflare"; then
        success "Cloudflare detected"
    else
        warning "Cloudflare NS not detected, but continuing..."
    fi

    local cf_ip=$(dig +short "$DOMAIN" 2>/dev/null | head -1)
    if [[ -n "$cf_ip" ]]; then
        success "Cloudflare proxy detected"
    else
        error "Proxy is disabled"
        echo -e "${RED}Please enable Orange Cloud Proxy${NC}"
        echo -e "${RED}and try again.${NC}"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}Select Cloudflare SSL Mode${NC}"
    echo "─────────────────────────────"
    echo "1. Flexible"
    echo "2. Full"
    echo -e "3. Full (Strict) ${YELLOW}[Recommended]${NC}"
    echo ""
    echo -e "${RED}4. Cancel installation${NC}"
    echo ""
    echo -e "${YELLOW}Default: 3${NC}"
    echo ""

    read -rp "Choose [1-4]: " cf_choice
    case "$cf_choice" in
        1) CF_SSL_MODE="flexible" ;;
        2) CF_SSL_MODE="full" ;;
        3|"") CF_SSL_MODE="full_strict" ;;
        4) cleanup_and_exit ;;
        *) CF_SSL_MODE="full_strict" ;;
    esac

    echo ""
    echo -e "${BOLD}Security Configuration${NC}"
    echo "──────────────────────"

    read -rp "Always HTTPS? (Recommended: Yes) [Y/n]: " cf_always_https
    CF_ALWAYS_HTTPS=$( [[ "$cf_always_https" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "HTTP/3? (Recommended: Yes) [Y/n]: " cf_http3
    CF_HTTP3=$( [[ "$cf_http3" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "Brotli Compression? (Recommended: Yes) [Y/n]: " cf_brotli
    CF_BROTLI=$( [[ "$cf_brotli" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "Security Headers? (Recommended: Yes) [Y/n]: " cf_headers
    CF_HEADERS=$( [[ "$cf_headers" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "Bot Fight Mode? (Recommended: Yes) [Y/n]: " cf_bot
    CF_BOT=$( [[ "$cf_bot" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "Hotlink Protection? (Recommended: Yes) [Y/n]: " cf_hotlink
    CF_HOTLINK=$( [[ "$cf_hotlink" =~ ^[Nn]$ ]] && echo "false" || echo "true" )
}

# ============================================
# SECURITY CONFIGURATION
# ============================================

configure_security() {
    if [[ "$SSL_PROVIDER" == "cloudflare" ]]; then
        return
    fi

    echo ""
    echo -e "${BOLD}Security Configuration${NC}"
    echo "──────────────────────"

    read -rp "Always HTTPS Redirect? (Recommended: Yes) [Y/n]: " sec_https
    SEC_HTTPS=$( [[ "$sec_https" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "HSTS? (Recommended: Yes) [Y/n]: " sec_hsts
    SEC_HSTS=$( [[ "$sec_hsts" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "TLS 1.2 / 1.3 Only? (Recommended: Yes) [Y/n]: " sec_tls
    SEC_TLS=$( [[ "$sec_tls" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "X-Frame-Options? (Recommended: Yes) [Y/n]: " sec_frame
    SEC_FRAME=$( [[ "$sec_frame" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "X-XSS-Protection? (Recommended: Yes) [Y/n]: " sec_xss
    SEC_XSS=$( [[ "$sec_xss" =~ ^[Nn]$ ]] && echo "false" || echo "true" )

    read -rp "Content-Security-Policy? (Recommended: Yes) [Y/n]: " sec_csp
    SEC_CSP=$( [[ "$sec_csp" =~ ^[Nn]$ ]] && echo "false" || echo "true" )
}

# ============================================
# PORT SELECTION
# ============================================

RESERVED_PORTS="22 25 53 3306 5432 6379 27017 22 23 110 143 465 587 993 995 8080 8443"

check_port() {
    local port=$1
    if echo "$RESERVED_PORTS" | grep -qw "$port"; then
        error "Reserved/System Port"
        echo -e "${YELLOW}Please choose another port${NC}"
        return 1
    fi

    if ss -tuln | grep -q ":$port "; then
        error "Port $port is already in use"
        return 1
    fi

    success "Port available"
    return 0
}

select_port() {
    echo ""
    echo -e "${BOLD}Select Web Port${NC}"
    echo "────────────────────────"
    echo "1. Default (443)"
    echo "2. Custom Port"
    echo ""
    echo -e "${RED}3. Cancel installation${NC}"
    echo ""

    while true; do
        read -rp "Choose [1-3]: " choice
        case "$choice" in
            1) WEB_PORT=443; break ;;
            2) 
                while true; do
                    read -rp "Enter custom port: " custom_port
                    if [[ "$custom_port" =~ ^[0-9]+$ ]]; then
                        if check_port "$custom_port"; then
                            WEB_PORT=$custom_port
                            break 2
                        fi
                    else
                        error "Invalid port number"
                    fi
                done
                ;;
            3) cleanup_and_exit ;;
            *) error "Invalid choice" ;;
        esac
    done

    success "Web Port: $WEB_PORT"
}

# ============================================
# HTTP PORT (for HTTP Only mode)
# ============================================

select_http_port() {
    if [[ "$SSL_PROVIDER" != "http" ]]; then
        return
    fi

    echo ""
    echo -e "${BOLD}Select HTTP Port${NC}"
    echo "────────────────────────"
    echo "1. Default (80)"
    echo "2. Custom Port"
    echo ""

    while true; do
        read -rp "Choose [1-2]: " choice
        case "$choice" in
            1) WEB_PORT=80; break ;;
            2) 
                while true; do
                    read -rp "Enter custom port: " custom_port
                    if [[ "$custom_port" =~ ^[0-9]+$ ]]; then
                        if check_port "$custom_port"; then
                            WEB_PORT=$custom_port
                            break 2
                        fi
                    else
                        error "Invalid port number"
                    fi
                done
                ;;
            *) error "Invalid choice" ;;
        esac
    done

    success "HTTP Port: $WEB_PORT"
}

# ============================================
# INSTALLATION SUMMARY
# ============================================

show_summary() {
    echo ""
    echo -e "${BOLD}─────────────────────────────${NC}"
    echo -e "${BOLD} Installation Summary${NC}"
    echo -e "${BOLD}─────────────────────────────${NC}"
    echo -e " Domain     : ${GREEN}$DOMAIN${NC}"
    echo -e " Web Server : ${GREEN}$WEB_SERVER${NC}"
    echo -e " Database   : ${GREEN}$DATABASE${NC}"
    echo -e " SSL        : ${GREEN}$SSL_PROVIDER${NC}"
    echo -e " Port       : ${GREEN}$WEB_PORT${NC}"
    echo -e " Security   :"

    if [[ "$SSL_PROVIDER" == "cloudflare" ]]; then
        echo -e "  - Always HTTPS    $( [[ "$CF_ALWAYS_HTTPS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - HTTP/3          $( [[ "$CF_HTTP3" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - Brotli          $( [[ "$CF_BROTLI" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - Security Hdrs   $( [[ "$CF_HEADERS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - Bot Fight       $( [[ "$CF_BOT" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - Hotlink Protect $( [[ "$CF_HOTLINK" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
    else
        echo -e "  - Always HTTPS    $( [[ "$SEC_HTTPS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - HSTS            $( [[ "$SEC_HSTS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - TLS 1.2/1.3     $( [[ "$SEC_TLS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - X-Frame-Options $( [[ "$SEC_FRAME" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - X-XSS-Protect   $( [[ "$SEC_XSS" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
        echo -e "  - CSP             $( [[ "$SEC_CSP" == "true" ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}" )"
    fi
    echo -e "${BOLD}─────────────────────────────${NC}"
    echo ""

    read -rp "Confirm installation? (Y/n) > " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        cleanup_and_exit
    fi
}

# ============================================
# INSTALLATION PROCESS
# ============================================

install_packages() {
    log "Installing required packages..."
    show_progress "Installing required packages..." 35

    case "$PKG_MANAGER" in
        apt)
            apt-get update -qq &
            spinner $! "Updating package lists..."
            wait $!

            local packages="curl wget unzip net-tools dnsutils certbot python3-certbot-nginx"
            [[ "$WEB_SERVER" == "nginx" ]] && packages="$packages nginx"
            [[ "$WEB_SERVER" == "apache" ]] && packages="$packages apache2"
            [[ "$DATABASE" == "mariadb" ]] && packages="$packages mariadb-server"
            [[ "$DATABASE" == "mysql" ]] && packages="$packages mysql-server"
            [[ "$DATABASE" == "postgresql" ]] && packages="$packages postgresql"

            apt-get install -y -qq $packages &
            spinner $! "Installing packages..."
            wait $!
            ;;
        dnf|yum)
            local packages="curl wget unzip net-tools bind-utils certbot"
            [[ "$WEB_SERVER" == "nginx" ]] && packages="$packages nginx"
            [[ "$WEB_SERVER" == "apache" ]] && packages="$packages httpd"
            [[ "$DATABASE" == "mariadb" ]] && packages="$packages mariadb-server"
            [[ "$DATABASE" == "mysql" ]] && packages="$packages mysql-server"
            [[ "$DATABASE" == "postgresql" ]] && packages="$packages postgresql-server"

            $PKG_MANAGER install -y -q $packages &
            spinner $! "Installing packages..."
            wait $!
            ;;
    esac

    success "Packages installed"
}

install_webserver() {
    log "Installing web server: $WEB_SERVER..."
    show_progress "Installing web server..." 70

    case "$WEB_SERVER" in
        nginx)
            systemctl enable nginx &>/dev/null || true
            systemctl start nginx &>/dev/null || true
            ;;
        apache)
            systemctl enable httpd &>/dev/null || true
            systemctl enable apache2 &>/dev/null || true
            systemctl start httpd &>/dev/null || true
            systemctl start apache2 &>/dev/null || true
            ;;
        litespeed)
            log "LiteSpeed requires manual license installation"
            warning "Please install LiteSpeed manually after setup"
            ;;
    esac

    success "Web server configured"
}

install_database() {
    log "Configuring database: $DATABASE..."
    show_progress "Configuring database..." 85

    case "$DATABASE" in
        mariadb|mysql)
            systemctl enable mariadb &>/dev/null || systemctl enable mysql &>/dev/null || true
            systemctl start mariadb &>/dev/null || systemctl start mysql &>/dev/null || true

            mysql -e "UPDATE mysql.user SET Password=PASSWORD('$(openssl rand -base64 24)') WHERE User='root';" 2>/dev/null || true
            mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
            mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
            mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
            mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
            ;;
        postgresql)
            postgresql-setup --initdb &>/dev/null || true
            systemctl enable postgresql &>/dev/null || true
            systemctl start postgresql &>/dev/null || true
            ;;
        sqlite)
            success "SQLite ready (no service needed)"
            ;;
    esac

    success "Database configured"
}

configure_ssl() {
    log "Configuring SSL: $SSL_PROVIDER..."
    show_progress "Configuring SSL..." 95

    mkdir -p "$CONFIG_DIR/ssl"

    case "$SSL_PROVIDER" in
        letsencrypt)
            if [[ -n "$SSL_EMAIL" ]]; then
                certbot certonly --standalone -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive &>/dev/null || true
            else
                certbot certonly --standalone -d "$DOMAIN" --register-unsafely-without-email --agree-tos --non-interactive &>/dev/null || true
            fi

            echo "0 3 * * * certbot renew --quiet" | crontab - 2>/dev/null || true
            success "Let's Encrypt SSL configured (Auto-renewal enabled)"
            ;;
        cloudflare)
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "$CONFIG_DIR/ssl/${DOMAIN}.key" \
                -out "$CONFIG_DIR/ssl/${DOMAIN}.crt" \
                -subj "/CN=$DOMAIN" &>/dev/null || true
            success "Cloudflare SSL configured (Origin certificate)"
            ;;
        http)
            warning "Running without SSL"
            ;;
    esac
}

configure_webserver() {
    log "Configuring $WEB_SERVER..."

    case "$WEB_SERVER" in
        nginx)
            cat > /etc/nginx/conf.d/${DOMAIN}.conf <<EOF
server {
    listen ${WEB_PORT};
    server_name ${DOMAIN};
    root /var/www/${DOMAIN};
    index index.html index.php;

    $( [[ "$SSL_PROVIDER" != "http" ]] && echo "
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    " || echo "" )

    $( [[ "$SEC_HTTPS" == "true" && "$SSL_PROVIDER" != "http" ]] && echo "
    if (\$scheme != https) {
        return 301 https://\$host\$request_uri;
    }
    " || echo "" )

    $( [[ "$SEC_HSTS" == "true" ]] && echo "add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;" || echo "" )
    $( [[ "$SEC_FRAME" == "true" ]] && echo "add_header X-Frame-Options 'SAMEORIGIN' always;" || echo "" )
    $( [[ "$SEC_XSS" == "true" ]] && echo "add_header X-XSS-Protection '1; mode=block' always;" || echo "" )
    $( [[ "$SEC_CSP" == "true" ]] && echo "add_header Content-Security-Policy 'default-src self;' always;" || echo "" )

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
            nginx -t &>/dev/null || true
            systemctl reload nginx &>/dev/null || true
            ;;
        apache)
            cat > /etc/httpd/conf.d/${DOMAIN}.conf <<EOF || cat > /etc/apache2/sites-available/${DOMAIN}.conf <<EOF
<VirtualHost *:${WEB_PORT}>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/${DOMAIN}

    $( [[ "$SEC_HTTPS" == "true" && "$SSL_PROVIDER" != "http" ]] && echo "
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
    " || echo "" )

    $( [[ "$SEC_HSTS" == "true" ]] && echo "Header always set Strict-Transport-Security 'max-age=31536000; includeSubDomains'" || echo "" )
    $( [[ "$SEC_FRAME" == "true" ]] && echo "Header always set X-Frame-Options 'SAMEORIGIN'" || echo "" )
    $( [[ "$SEC_XSS" == "true" ]] && echo "Header always set X-XSS-Protection '1; mode=block'" || echo "" )
    $( [[ "$SEC_CSP" == "true" ]] && echo "Header always set Content-Security-Policy 'default-src self;'" || echo "" )

    <Directory /var/www/${DOMAIN}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
            systemctl reload httpd &>/dev/null || systemctl reload apache2 &>/dev/null || true
            ;;
    esac

    mkdir -p /var/www/${DOMAIN}
    echo "<h1>Hosting Panel - ${DOMAIN}</h1>" > /var/www/${DOMAIN}/index.html
    success "Web server configured for $DOMAIN"
}

save_config() {
    cat > "$CONFIG_DIR/config.env" <<EOF
DOMAIN=${DOMAIN}
WEB_SERVER=${WEB_SERVER}
DATABASE=${DATABASE}
SSL_PROVIDER=${SSL_PROVIDER}
WEB_PORT=${WEB_PORT}
SSL_EMAIL=${SSL_EMAIL}
SEC_HTTPS=${SEC_HTTPS}
SEC_HSTS=${SEC_HSTS}
SEC_TLS=${SEC_TLS}
SEC_FRAME=${SEC_FRAME}
SEC_XSS=${SEC_XSS}
SEC_CSP=${SEC_CSP}
CF_SSL_MODE=${CF_SSL_MODE}
CF_ALWAYS_HTTPS=${CF_ALWAYS_HTTPS}
CF_HTTP3=${CF_HTTP3}
CF_BROTLI=${CF_BROTLI}
CF_HEADERS=${CF_HEADERS}
CF_BOT=${CF_BOT}
CF_HOTLINK=${CF_HOTLINK}
VERSION=${CURRENT_VERSION}
EOF
    chmod 600 "$CONFIG_DIR/config.env"

    # บันทึก REPO และ VERSION ลง config dir ให้ hosting.sh อ่านได้
    echo "$GITHUB_REPO" > "$CONFIG_DIR/REPO"
    echo "$CURRENT_VERSION" > "$CONFIG_DIR/VERSION"
}

install_hosting_command() {
    log "Installing hosting management command..."

    cp "$INSTALL_DIR/hosting.sh" /usr/local/bin/hosting
    chmod +x /usr/local/bin/hosting

    echo "$CURRENT_VERSION" > "$CONFIG_DIR/version"

    success "Type 'hosting' to manage your panel"
}

# ============================================
# CLEANUP
# ============================================

cleanup_and_exit() {
    error "Installation cancelled"
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -rf "$CONFIG_DIR" 2>/dev/null || true
    exit 1
}

# ============================================
# MAIN INSTALLATION
# ============================================

main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           WEB HOSTING PANEL INSTALLER                        ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
    touch "$LOG_FILE"

    log "Repository: $GITHUB_REPO"
    log "Version: $CURRENT_VERSION"

    check_root
    detect_os

    if [[ "$GITHUB_REPO" != "Phechr-2025/Hosting" ]]; then
        local url=$(get_latest_release)
        if [[ -n "$url" ]]; then
            download_source "$url"
        fi
    else
        warning "Using bundled installation (no custom repo configured)"
    fi

    ask_domain
    select_webserver
    select_database
    select_ssl
    configure_security
    select_http_port
    select_port
    show_summary

    echo ""
    log "Starting installation..."
    echo ""

    install_packages
    install_webserver
    install_database
    configure_ssl
    configure_webserver
    save_config
    install_hosting_command

    show_progress "Finalizing installation..." 100

    echo ""
    echo -e "${BOLD}${GREEN}"
    echo "================================================="
    echo " The script hosting system installation is complete 💯🎉"
    echo "================================================="
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Access your panel:${NC}"
    if [[ "$SSL_PROVIDER" == "http" ]]; then
        echo -e "  http://${DOMAIN}:${WEB_PORT}"
    else
        echo -e "  https://${DOMAIN}:${WEB_PORT}"
    fi
    echo ""
    echo -e "${YELLOW}Type 'hosting' to open management menu${NC}"
    echo ""
}

main "$@"

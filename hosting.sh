#!/bin/bash
# ============================================================
# Hosting Control Panel Management Script
# ============================================================

CONFIG_DIR="/etc/hosting-panel"
INSTALL_DIR="/opt/hosting-panel"
LOG_FILE="/var/log/hosting-panel.log"

# ============================================
# SINGLE SOURCE OF TRUTH - อ่านจากไฟล์เดียว
# ============================================
if [[ -f "$CONFIG_DIR/REPO" ]]; then
    GITHUB_REPO=$(cat "$CONFIG_DIR/REPO" | tr -d '[:space:]')
else
    GITHUB_REPO="Phechr-2025/Hosting"
fi

if [[ -f "$CONFIG_DIR/VERSION" ]]; then
    CURRENT_VERSION=$(cat "$CONFIG_DIR/VERSION" | tr -d '[:space:]')
else
    CURRENT_VERSION="v1.0.0"
fi

# Load main config
if [[ -f "$CONFIG_DIR/config.env" ]]; then
    source "$CONFIG_DIR/config.env"
else
    echo -e "\033[0;31mError: Hosting panel not installed or config missing\033[0m"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================
# UI FUNCTIONS
# ============================================

print_banner() {
    local version_text="Version $CURRENT_VERSION"
    local padding=$((50 - ${#version_text} / 2))

    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ██╗  ██╗ ██████╗ ███████╗████████╗██╗███╗   ██╗███████╗ ║"
    echo "║     ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝ ║"
    echo "║     ███████║██║   ██║███████╗   ██║   ██║██╔██╗ ██║███████╗ ║"
    echo "║     ██╔══██║██║   ██║╚════██║   ██║   ██║██║╚██╗██║╚════██║ ║"
    echo "║     ██║  ██║╚██████╔╝███████║   ██║   ██║██║ ╚████║███████║ ║"
    echo "║     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝ ║"
    echo "║                                                              ║"
    echo "║           HOSTING CONTROL PANEL MANAGEMENT SCRIPT              ║"
    echo "║                                                              ║"
    printf "║%*s%s%*s║\n" $((25-${#version_text}/2)) "" "$version_text" $((25-${#version_text}/2-${#version_text}%2)) ""
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_menu() {
    echo -e "${BOLD}${YELLOW}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}1.${NC} Exit Script                                          ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}2.${NC} Update                                               ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}3.${NC} Uninstall                                            ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}4.${NC} Change Domain                                        ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}5.${NC} Change Web Server                                    ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}6.${NC} Change Database                                      ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}7.${NC} Change SSL Provider                                  ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}8.${NC} Change Web Port                                      ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC}  ${MAGENTA}9.${NC} View Current Settings                                ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC} ${MAGENTA}10.${NC} Reset Username & Password                            ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC} ${MAGENTA}11.${NC} Restart the Website                                  ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}│${NC} ${MAGENTA}12.${NC} Back up Data                                         ${BOLD}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ============================================
# MENU FUNCTIONS
# ============================================

cmd_exit() {
    echo -e "${GREEN}Exiting...${NC}"
    exit 0
}

cmd_update() {
    echo -e "${CYAN}Checking version...${NC}"
    echo -e "${CYAN}Repository: $GITHUB_REPO${NC}"
    echo ""

    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    local latest_version=""
    local release_url=""

    if command -v curl &>/dev/null; then
        latest_version=$(curl -sL "$api_url" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    elif command -v wget &>/dev/null; then
        latest_version=$(wget -qO- "$api_url" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    fi

    if [[ -z "$latest_version" ]]; then
        echo -e "${YELLOW}Cannot check for updates (GitHub API unavailable)${NC}"
        echo -e "${YELLOW}Current Version: $CURRENT_VERSION${NC}"
        return
    fi

    echo -e " Current Version : ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e " Latest Version  : ${GREEN}$latest_version${NC}"
    echo ""

    if [[ "$latest_version" == "$CURRENT_VERSION" ]]; then
        echo -e "${GREEN}✅ Already up to date ($CURRENT_VERSION)${NC}"
        return
    fi

    echo -e "${YELLOW} New version available!${NC}"
    read -rp " Proceed with update? (Y/n) > " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        return
    fi

    read -rp " Do you confirm that you will proceed with the update? (Y/N) > " confirm2
    if [[ "$confirm2" =~ ^[Nn]$ ]]; then
        return
    fi

    echo -e "${CYAN}Updating to $latest_version...${NC}"

    cp "$CONFIG_DIR/config.env" "/tmp/hosting-panel-backup.env"

    local zip_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${latest_version}.zip"
    local temp_dir=$(mktemp -d)

    if curl -sL "$zip_url" -o "${temp_dir}/update.zip" 2>/dev/null; then
        unzip -q "${temp_dir}/update.zip" -d "$temp_dir"
        local extracted=$(find "$temp_dir" -maxdepth 1 -type d | grep -v "^${temp_dir}$" | head -1)
        if [[ -d "$extracted" ]]; then
            cp -r "$extracted"/* "$INSTALL_DIR/"
            cp "/tmp/hosting-panel-backup.env" "$CONFIG_DIR/config.env"
            echo "$latest_version" > "$CONFIG_DIR/VERSION"
            echo "$latest_version" > "$CONFIG_DIR/version"
            sed -i "s/VERSION=.*/VERSION=$latest_version/" "$CONFIG_DIR/config.env"
            CURRENT_VERSION="$latest_version"
            echo -e "${GREEN}✅ Updated to $latest_version${NC}"
            echo -e "${YELLOW}Please restart the website (Menu 11)${NC}"
        fi
    else
        echo -e "${RED}❌ Update failed${NC}"
    fi

    rm -rf "$temp_dir" "/tmp/hosting-panel-backup.env"
}

cmd_uninstall() {
    read -rp "Should we proceed with the uninstallation? (y/n) > " confirm1
    if [[ "$confirm1" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Uninstallation cancelled${NC}"
        return
    fi

    read -rp "Are you 100% sure to proceed with the uninstallation? (y/n) > " confirm2
    if [[ "$confirm2" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Uninstallation cancelled${NC}"
        return
    fi

    echo -e "${RED}Uninstalling hosting panel...${NC}"

    systemctl stop nginx &>/dev/null || true
    systemctl stop apache2 &>/dev/null || true
    systemctl stop httpd &>/dev/null || true
    systemctl stop mariadb &>/dev/null || true
    systemctl stop mysql &>/dev/null || true
    systemctl stop postgresql &>/dev/null || true

    rm -rf "$INSTALL_DIR"
    rm -rf "$CONFIG_DIR"
    rm -f /usr/local/bin/hosting

    echo -e "${GREEN}✅ Hosting panel uninstalled successfully${NC}"
    exit 0
}

cmd_change_domain() {
    echo -e "${CYAN}Please enter the domain that points to this server${NC}"
    echo -e "${YELLOW}1. Cancel domain change${NC}"
    echo ""
    read -rp "Domain: " new_domain

    if [[ "$new_domain" == "1" ]]; then
        echo -e "${YELLOW}Domain change cancelled${NC}"
        return
    fi

    if [[ -z "$new_domain" ]]; then
        echo -e "${RED}Domain cannot be empty${NC}"
        return
    fi

    local server_ip=$(hostname -I | awk '{print $1}')
    local a_record=$(dig +short A "$new_domain" 2>/dev/null || echo "")

    if [[ "$a_record" != "$server_ip" ]]; then
        echo -e "${RED}❌ Domain does not point to this server${NC}"
        echo -e "${RED}Expected: $server_ip, Found: $a_record${NC}"
        return
    fi

    local old_domain="$DOMAIN"
    sed -i "s/DOMAIN=.*/DOMAIN=$new_domain/" "$CONFIG_DIR/config.env"

    if [[ "$WEB_SERVER" == "nginx" ]]; then
        mv /etc/nginx/conf.d/${old_domain}.conf /etc/nginx/conf.d/${new_domain}.conf 2>/dev/null || true
        sed -i "s/$old_domain/$new_domain/g" /etc/nginx/conf.d/${new_domain}.conf 2>/dev/null || true
        systemctl reload nginx
    elif [[ "$WEB_SERVER" == "apache" ]]; then
        mv /etc/httpd/conf.d/${old_domain}.conf /etc/httpd/conf.d/${new_domain}.conf 2>/dev/null || true
        mv /etc/apache2/sites-available/${old_domain}.conf /etc/apache2/sites-available/${new_domain}.conf 2>/dev/null || true
        sed -i "s/$old_domain/$new_domain/g" /etc/httpd/conf.d/${new_domain}.conf 2>/dev/null || true
        sed -i "s/$old_domain/$new_domain/g" /etc/apache2/sites-available/${new_domain}.conf 2>/dev/null || true
        systemctl reload httpd 2>/dev/null || systemctl reload apache2
    fi

    mv /var/www/${old_domain} /var/www/${new_domain} 2>/dev/null || true

    echo -e "${GREEN}✅ Domain changed to $new_domain${NC}"
    DOMAIN="$new_domain"
}

cmd_change_webserver() {
    echo -e "${BOLD}Select New Web Server${NC}"
    echo "────────────────────────"
    echo "1. Nginx"
    echo "2. Apache"
    echo "3. LiteSpeed"
    echo ""
    echo -e "${RED}4. Cancel${NC}"
    echo ""

    read -rp "Choose [1-4]: " choice
    case "$choice" in
        1) new_server="nginx" ;;
        2) new_server="apache" ;;
        3) new_server="litespeed" ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; return ;;
    esac

    if [[ "$new_server" == "$WEB_SERVER" ]]; then
        echo -e "${YELLOW}Already using $new_server${NC}"
        return
    fi

    systemctl stop nginx &>/dev/null || true
    systemctl stop apache2 &>/dev/null || true
    systemctl stop httpd &>/dev/null || true

    case "$PKG_MANAGER" in
        apt)
            [[ "$new_server" == "nginx" ]] && apt-get install -y -qq nginx
            [[ "$new_server" == "apache" ]] && apt-get install -y -qq apache2
            ;;
        dnf|yum)
            [[ "$new_server" == "nginx" ]] && $PKG_MANAGER install -y -q nginx
            [[ "$new_server" == "apache" ]] && $PKG_MANAGER install -y -q httpd
            ;;
    esac

    sed -i "s/WEB_SERVER=.*/WEB_SERVER=$new_server/" "$CONFIG_DIR/config.env"
    WEB_SERVER="$new_server"
    echo -e "${GREEN}✅ Web server changed to $new_server${NC}"
    echo -e "${YELLOW}Please restart the website (Menu 11)${NC}"
}

cmd_change_database() {
    echo -e "${BOLD}Select New Database${NC}"
    echo "────────────────────────"
    echo "1. MariaDB"
    echo "2. MySQL"
    echo "3. PostgreSQL"
    echo "4. SQLite"
    echo ""
    echo -e "${RED}5. Cancel${NC}"
    echo ""

    read -rp "Choose [1-5]: " choice
    case "$choice" in
        1) new_db="mariadb" ;;
        2) new_db="mysql" ;;
        3) new_db="postgresql" ;;
        4) new_db="sqlite" ;;
        5) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; return ;;
    esac

    if [[ "$new_db" == "$DATABASE" ]]; then
        echo -e "${YELLOW}Already using $new_db${NC}"
        return
    fi

    case "$PKG_MANAGER" in
        apt)
            [[ "$new_db" == "mariadb" ]] && apt-get install -y -qq mariadb-server
            [[ "$new_db" == "mysql" ]] && apt-get install -y -qq mysql-server
            [[ "$new_db" == "postgresql" ]] && apt-get install -y -qq postgresql
            ;;
        dnf|yum)
            [[ "$new_db" == "mariadb" ]] && $PKG_MANAGER install -y -q mariadb-server
            [[ "$new_db" == "mysql" ]] && $PKG_MANAGER install -y -q mysql-server
            [[ "$new_db" == "postgresql" ]] && $PKG_MANAGER install -y -q postgresql-server
            ;;
    esac

    sed -i "s/DATABASE=.*/DATABASE=$new_db/" "$CONFIG_DIR/config.env"
    DATABASE="$new_db"
    echo -e "${GREEN}✅ Database changed to $new_db${NC}"
}

cmd_change_ssl() {
    echo -e "${BOLD}Select New SSL Provider${NC}"
    echo "────────────────────────"
    echo "1. Let's Encrypt"
    echo "2. Cloudflare SSL"
    echo "3. HTTP Only"
    echo ""
    echo -e "${RED}4. Cancel${NC}"
    echo ""

    read -rp "Choose [1-4]: " choice
    case "$choice" in
        1) new_ssl="letsencrypt" ;;
        2) new_ssl="cloudflare" ;;
        3) new_ssl="http" ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; return ;;
    esac

    if [[ "$new_ssl" == "$SSL_PROVIDER" ]]; then
        echo -e "${YELLOW}Already using $new_ssl${NC}"
        return
    fi

    sed -i "s/SSL_PROVIDER=.*/SSL_PROVIDER=$new_ssl/" "$CONFIG_DIR/config.env"
    SSL_PROVIDER="$new_ssl"
    echo -e "${GREEN}✅ SSL provider changed to $new_ssl${NC}"
    echo -e "${YELLOW}Please restart the website (Menu 11)${NC}"
}

cmd_change_port() {
    read -rp "Enter new web port: " new_port
    if [[ ! "$new_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid port${NC}"
        return
    fi

    if ss -tuln | grep -q ":$new_port "; then
        echo -e "${RED}Port $new_port is already in use${NC}"
        return
    fi

    sed -i "s/WEB_PORT=.*/WEB_PORT=$new_port/" "$CONFIG_DIR/config.env"
    WEB_PORT="$new_port"
    echo -e "${GREEN}✅ Web port changed to $new_port${NC}"
    echo -e "${YELLOW}Please restart the website (Menu 11)${NC}"
}

cmd_view_settings() {
    echo ""
    echo -e "${BOLD}${CYAN}─────────────────────────────${NC}"
    echo -e "${BOLD}${CYAN}    Current Settings${NC}"
    echo -e "${BOLD}${CYAN}─────────────────────────────${NC}"
    echo -e " Repository   : ${GREEN}$GITHUB_REPO${NC}"
    echo -e " Domain       : ${GREEN}$DOMAIN${NC}"
    echo -e " Web Server   : ${GREEN}$WEB_SERVER${NC}"
    echo -e " Database     : ${GREEN}$DATABASE${NC}"
    echo -e " SSL Provider : ${GREEN}$SSL_PROVIDER${NC}"
    echo -e " Web Port     : ${GREEN}$WEB_PORT${NC}"
    echo -e " Panel Version: ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BOLD}${CYAN}─────────────────────────────${NC}"
    echo ""
}

cmd_reset_credentials() {
    echo -e "${CYAN}Reset Username & Password${NC}"
    echo ""
    read -rp "Enter new username: " new_user
    read -rsp "Enter new password: " new_pass
    echo ""

    if [[ -z "$new_user" || -z "$new_pass" ]]; then
        echo -e "${RED}Username and password cannot be empty${NC}"
        return
    fi

    echo "$(echo -n "$new_user" | base64):$(echo -n "$new_pass" | base64)" > "$CONFIG_DIR/.htpasswd"
    chmod 600 "$CONFIG_DIR/.htpasswd"

    echo -e "${GREEN}✅ Credentials updated${NC}"
}

cmd_restart() {
    echo -e "${CYAN}Restarting website services...${NC}"

    if [[ "$WEB_SERVER" == "nginx" ]]; then
        systemctl restart nginx
    elif [[ "$WEB_SERVER" == "apache" ]]; then
        systemctl restart httpd || systemctl restart apache2
    fi

    if [[ "$DATABASE" == "mariadb" || "$DATABASE" == "mysql" ]]; then
        systemctl restart mariadb || systemctl restart mysql
    elif [[ "$DATABASE" == "postgresql" ]]; then
        systemctl restart postgresql
    fi

    echo -e "${GREEN}✅ Services restarted${NC}"
}

cmd_backup() {
    local backup_dir="/var/backups/hosting-panel"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/backup_${timestamp}.tar.gz"

    mkdir -p "$backup_dir"

    echo -e "${CYAN}Creating backup...${NC}"

    tar -czf "$backup_file" \
        -C / "$CONFIG_DIR" \
        -C / "$INSTALL_DIR" \
        -C / "var/www" \
        2>/dev/null || true

    if [[ -f "$backup_file" ]]; then
        echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
    else
        echo -e "${RED}❌ Backup failed${NC}"
    fi
}

# ============================================
# MAIN LOOP
# ============================================

main() {
    while true; do
        clear
        print_banner
        print_menu

        read -rp "Select option [1-12]: " choice

        case "$choice" in
            1) cmd_exit ;;
            2) cmd_update ;;
            3) cmd_uninstall ;;
            4) cmd_change_domain ;;
            5) cmd_change_webserver ;;
            6) cmd_change_database ;;
            7) cmd_change_ssl ;;
            8) cmd_change_port ;;
            9) cmd_view_settings ;;
            10) cmd_reset_credentials ;;
            11) cmd_restart ;;
            12) cmd_backup ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        echo ""
        read -rp "Press Enter to continue..."
    done
}

main

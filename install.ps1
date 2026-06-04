
#Requires -RunAsAdministrator
# ============================================================
# Web Hosting Panel Installer for Windows
# ============================================================

param()

# ============================================
# SINGLE SOURCE OF TRUTH - อ่านจากไฟล์เดียว
# ============================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (Test-Path "$ScriptDir\REPO") {
    $GITHUB_REPO = (Get-Content "$ScriptDir\REPO" -Raw).Trim()
} else {
    $GITHUB_REPO = "Phechr-2025/Hosting"
}

if (Test-Path "$ScriptDir\VERSION") {
    $CURRENT_VERSION = (Get-Content "$ScriptDir\VERSION" -Raw).Trim()
} else {
    $CURRENT_VERSION = "v1.0.0"
}

# ============================================
# CONFIG
# ============================================
$INSTALL_DIR = "C:\Program Files\Hosting-Panel"
$CONFIG_DIR = "C:\ProgramData\Hosting-Panel"
$LOG_FILE = "$CONFIG_DIR\install.log"

# Colors
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$NC = "`e[0m"
$Bold = "`e[1m"

# ============================================
# UTILITY FUNCTIONS
# ============================================

function Log {
    param($Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "${Cyan}[$timestamp]${NC} $Message"
    Add-Content -Path $LOG_FILE -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

function Error {
    param($Message)
    Write-Host "${Red}❌ $Message${NC}"
    Add-Content -Path $LOG_FILE -Value "[ERROR] $Message" -ErrorAction SilentlyContinue
}

function Success {
    param($Message)
    Write-Host "${Green}✅ $Message${NC}"
    Add-Content -Path $LOG_FILE -Value "[SUCCESS] $Message" -ErrorAction SilentlyContinue
}

function Info {
    param($Message)
    Write-Host "${Blue}ℹ️  $Message${NC}"
}

function Warning {
    param($Message)
    Write-Host "${Yellow}⚠️  $Message${NC}"
}

function Show-Progress {
    param($Text, $Percent)
    $width = 30
    $filled = [math]::Floor($Percent * $width / 100)
    $empty = $width - $filled
    $bar = "█" * $filled + "░" * $empty
    Write-Host ""
    Write-Host "${Bold}$Text${NC}"
    Write-Host "[$bar] $Percent%"
    Write-Host ""
}

function Show-Spinner {
    param($ScriptBlock, $Message)
    $spin = @("⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷")
    $i = 0
    $job = Start-Job -ScriptBlock $ScriptBlock
    while ($job.State -eq "Running") {
        $i = ($i + 1) % 8
        Write-Host "`r${Cyan}$($spin[$i])${NC} $Message" -NoNewline
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r${Green}✓${NC} $Message"
    Receive-Job -Job $job | Out-Null
    Remove-Job -Job $job
}

# ============================================
# SYSTEM CHECKS
# ============================================

function Check-Admin {
    Log "Checking administrator permission..."
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Error "Administrator permission required"
        Write-Host ""
        Write-Host "${Yellow}Windows:${NC} Run PowerShell as Administrator"
        exit 1
    }
    Success "Administrator detected"
}

function Get-LatestRelease {
    Log "Fetching latest release from GitHub..."
    Log "Repository: $GITHUB_REPO"
    $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $script:CURRENT_VERSION = $release.tag_name
        $zipUrl = $release.zipball_url
        if (-not $zipUrl) {
            $zipUrl = "https://github.com/$GITHUB_REPO/archive/refs/tags/$($script:CURRENT_VERSION).zip"
        }
        Success "Latest version: $($script:CURRENT_VERSION)"
        return $zipUrl
    } catch {
        Warning "Cannot fetch from GitHub, using bundled version: $CURRENT_VERSION"
        return $null
    }
}

function Download-Source {
    param($Url)
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    Log "Downloading source code..."
    Show-Progress "Downloading latest release..." 10

    $zipPath = "$tempDir\source.zip"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -ErrorAction Stop
        Success "Download complete"
    } catch {
        Error "Download failed"
        exit 1
    }

    Show-Progress "Extracting source code..." 20
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    $extracted = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
    if ($extracted) {
        Copy-Item -Path "$($extracted.FullName)\*" -Destination $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Success "Source code ready"
}

# ============================================
# DOMAIN VALIDATION
# ============================================

function Get-ServerIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) }
    return $ip
}

function Check-DNS {
    param($Domain)
    $serverIp = Get-ServerIP
    Log "Checking DNS records for $Domain..."

    try {
        $aRecord = [System.Net.Dns]::GetHostAddresses($Domain) | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1
        $aRecordIp = $aRecord.IPAddressToString
    } catch {
        $aRecordIp = $null
    }

    if ($aRecordIp -eq $serverIp) {
        Success "A Record matches: $serverIp"
        return $true
    } else {
        Error "Domain does not point to this VPS"
        Write-Host "${Red}Expected IP: $serverIp${NC}"
        Write-Host "${Red}Found A Record: $aRecordIp${NC}"
        Write-Host ""
        Write-Host "${Yellow}Please ensure your domain's A record points to:${NC} $serverIp"
        return $false
    }
}

function Ask-Domain {
    while ($true) {
        Write-Host ""
        Write-Host "${Bold}Please enter the domain that points to this server${NC}"
        Write-Host "${Yellow}(Example: example.com)${NC}"
        Write-Host ""
        $script:DOMAIN = Read-Host "Domain"

        if ([string]::IsNullOrWhiteSpace($script:DOMAIN)) {
            Error "Domain cannot be empty"
            continue
        }

        if ($script:DOMAIN -eq "1") {
            Cleanup-AndExit
        }

        if (Check-DNS -Domain $script:DOMAIN) {
            break
        } else {
            Write-Host ""
            Write-Host "${Yellow}1. Cancel domain change${NC}"
            Write-Host "${Yellow}2. Try again${NC}"
            $choice = Read-Host ">"
            if ($choice -eq "1") { Cleanup-AndExit }
        }
    }
}

# ============================================
# SELECTIONS
# ============================================

function Select-WebServer {
    Write-Host ""
    Write-Host "${Bold}Select Web Server${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Nginx           ${Yellow}⭐ Recommended${NC}"
    Write-Host "2. Apache"
    Write-Host "3. LiteSpeed"
    Write-Host ""
    Write-Host "${Red}4. Cancel installation${NC}"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Choose [1-4]"
        switch ($choice) {
            "1" { $script:WEB_SERVER = "nginx"; break }
            "2" { $script:WEB_SERVER = "apache"; break }
            "3" { $script:WEB_SERVER = "litespeed"; break }
            "4" { Cleanup-AndExit }
            default { Error "Invalid choice" }
        }
        if ($script:WEB_SERVER) { break }
    }
    Success "Web Server: $WEB_SERVER"
}

function Select-Database {
    Write-Host ""
    Write-Host "${Bold}Select Database${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. MariaDB"
    Write-Host "2. MySQL"
    Write-Host "3. PostgreSQL"
    Write-Host "4. SQLite"
    Write-Host ""
    Write-Host "${Red}5. Cancel installation${NC}"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Choose [1-5]"
        switch ($choice) {
            "1" { $script:DATABASE = "mariadb"; break }
            "2" { $script:DATABASE = "mysql"; break }
            "3" { $script:DATABASE = "postgresql"; break }
            "4" { $script:DATABASE = "sqlite"; break }
            "5" { Cleanup-AndExit }
            default { Error "Invalid choice" }
        }
        if ($script:DATABASE) { break }
    }
    Success "Database: $DATABASE"
}

function Select-SSL {
    Write-Host ""
    Write-Host "${Bold}Select SSL Provider${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Let's Encrypt"
    Write-Host "2. Cloudflare SSL"
    Write-Host "3. HTTP Only"
    Write-Host ""
    Write-Host "${Red}4. Cancel installation${NC}"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Choose [1-4]"
        switch ($choice) {
            "1" { $script:SSL_PROVIDER = "letsencrypt"; Ask-LetsEncryptEmail; break }
            "2" { $script:SSL_PROVIDER = "cloudflare"; Check-Cloudflare; break }
            "3" { $script:SSL_PROVIDER = "http"; break }
            "4" { Cleanup-AndExit }
            default { Error "Invalid choice" }
        }
        if ($script:SSL_PROVIDER) { break }
    }
    Success "SSL: $SSL_PROVIDER"
}

function Ask-LetsEncryptEmail {
    Write-Host ""
    Write-Host "${Bold}Enter Email for SSL Notification${NC}"
    Write-Host "(Optional)"
    Write-Host ""
    Write-Host "${Yellow}Type 'n' to skip${NC}"
    Write-Host ""
    $email = Read-Host ">"
    if ($email -eq "n" -or $email -eq "N") {
        $script:SSL_EMAIL = ""
    } else {
        $script:SSL_EMAIL = $email
    }
}

function Check-Cloudflare {
    Log "Checking Cloudflare..."
    try {
        $nsRecords = Resolve-DnsName -Name $DOMAIN -Type NS -ErrorAction Stop | Select-Object -ExpandProperty NameHost
        if ($nsRecords -match "cloudflare") {
            Success "Cloudflare detected"
        } else {
            Warning "Cloudflare NS not detected, but continuing..."
        }
    } catch {
        Warning "Cannot check NS records"
    }

    Write-Host ""
    Write-Host "${Bold}Select Cloudflare SSL Mode${NC}"
    Write-Host "─────────────────────────────"
    Write-Host "1. Flexible"
    Write-Host "2. Full"
    Write-Host "3. Full (Strict) ${Yellow}[Recommended]${NC}"
    Write-Host ""
    Write-Host "${Red}4. Cancel installation${NC}"
    Write-Host ""
    Write-Host "${Yellow}Default: 3${NC}"
    Write-Host ""

    $cfChoice = Read-Host "Choose [1-4]"
    switch ($cfChoice) {
        "1" { $script:CF_SSL_MODE = "flexible" }
        "2" { $script:CF_SSL_MODE = "full" }
        "3" { $script:CF_SSL_MODE = "full_strict" }
        "4" { Cleanup-AndExit }
        default { $script:CF_SSL_MODE = "full_strict" }
    }

    Write-Host ""
    Write-Host "${Bold}Security Configuration${NC}"
    Write-Host "──────────────────────"
    $script:CF_ALWAYS_HTTPS = (Read-Host "Always HTTPS? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:CF_HTTP3 = (Read-Host "HTTP/3? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:CF_BROTLI = (Read-Host "Brotli Compression? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:CF_HEADERS = (Read-Host "Security Headers? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:CF_BOT = (Read-Host "Bot Fight Mode? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:CF_HOTLINK = (Read-Host "Hotlink Protection? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
}

function Configure-Security {
    if ($SSL_PROVIDER -eq "cloudflare") { return }

    Write-Host ""
    Write-Host "${Bold}Security Configuration${NC}"
    Write-Host "──────────────────────"
    $script:SEC_HTTPS = (Read-Host "Always HTTPS Redirect? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:SEC_HSTS = (Read-Host "HSTS? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:SEC_TLS = (Read-Host "TLS 1.2 / 1.3 Only? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:SEC_FRAME = (Read-Host "X-Frame-Options? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:SEC_XSS = (Read-Host "X-XSS-Protection? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
    $script:SEC_CSP = (Read-Host "Content-Security-Policy? (Recommended: Yes) [Y/n]") -notmatch "^[Nn]$"
}

function Check-Port {
    param($Port)
    $reserved = @(22, 25, 53, 3306, 5432, 6379, 27017, 23, 110, 143, 465, 587, 993, 995, 8080, 8443)
    if ($reserved -contains $Port) {
        Error "Reserved/System Port"
        Write-Host "${Yellow}Please choose another port${NC}"
        return $false
    }
    $inUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($inUse) {
        Error "Port $Port is already in use"
        return $false
    }
    Success "Port available"
    return $true
}

function Select-Port {
    Write-Host ""
    Write-Host "${Bold}Select Web Port${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Default (443)"
    Write-Host "2. Custom Port"
    Write-Host ""
    Write-Host "${Red}3. Cancel installation${NC}"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Choose [1-3]"
        switch ($choice) {
            "1" { $script:WEB_PORT = 443; break }
            "2" {
                while ($true) {
                    $customPort = Read-Host "Enter custom port"
                    if ($customPort -match "^\d+$") {
                        if (Check-Port -Port ([int]$customPort)) {
                            $script:WEB_PORT = [int]$customPort
                            break 2
                        }
                    } else {
                        Error "Invalid port number"
                    }
                }
            }
            "3" { Cleanup-AndExit }
            default { Error "Invalid choice" }
        }
        if ($script:WEB_PORT) { break }
    }
    Success "Web Port: $WEB_PORT"
}

function Select-HttpPort {
    if ($SSL_PROVIDER -ne "http") { return }
    Write-Host ""
    Write-Host "${Bold}Select HTTP Port${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Default (80)"
    Write-Host "2. Custom Port"
    Write-Host ""
    while ($true) {
        $choice = Read-Host "Choose [1-2]"
        switch ($choice) {
            "1" { $script:WEB_PORT = 80; break }
            "2" {
                while ($true) {
                    $customPort = Read-Host "Enter custom port"
                    if ($customPort -match "^\d+$") {
                        if (Check-Port -Port ([int]$customPort)) {
                            $script:WEB_PORT = [int]$customPort
                            break 2
                        }
                    } else {
                        Error "Invalid port number"
                    }
                }
            }
            default { Error "Invalid choice" }
        }
        if ($script:WEB_PORT) { break }
    }
    Success "HTTP Port: $WEB_PORT"
}

# ============================================
# SUMMARY & INSTALL
# ============================================

function Show-Summary {
    Write-Host ""
    Write-Host "${Bold}─────────────────────────────${NC}"
    Write-Host "${Bold} Installation Summary${NC}"
    Write-Host "${Bold}─────────────────────────────${NC}"
    Write-Host " Domain     : ${Green}$DOMAIN${NC}"
    Write-Host " Web Server : ${Green}$WEB_SERVER${NC}"
    Write-Host " Database   : ${Green}$DATABASE${NC}"
    Write-Host " SSL        : ${Green}$SSL_PROVIDER${NC}"
    Write-Host " Port       : ${Green}$WEB_PORT${NC}"
    Write-Host " Security   :"
    if ($SSL_PROVIDER -eq "cloudflare") {
        Write-Host "  - Always HTTPS    $(if ($CF_ALWAYS_HTTPS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - HTTP/3          $(if ($CF_HTTP3) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - Brotli          $(if ($CF_BROTLI) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - Security Hdrs   $(if ($CF_HEADERS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - Bot Fight       $(if ($CF_BOT) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - Hotlink Protect $(if ($CF_HOTLINK) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
    } else {
        Write-Host "  - Always HTTPS    $(if ($SEC_HTTPS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - HSTS            $(if ($SEC_HSTS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - TLS 1.2/1.3     $(if ($SEC_TLS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - X-Frame-Options $(if ($SEC_FRAME) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - X-XSS-Protect   $(if ($SEC_XSS) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
        Write-Host "  - CSP             $(if ($SEC_CSP) { "${Green}✅${NC}" } else { "${Red}❌${NC}" })"
    }
    Write-Host "${Bold}─────────────────────────────${NC}"
    Write-Host ""
    $confirm = Read-Host "Confirm installation? (Y/n)"
    if ($confirm -match "^[Nn]$") { Cleanup-AndExit }
}

function Install-Packages {
    Log "Installing required packages..."
    Show-Progress "Installing required packages..." 35

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Log "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    if ($WEB_SERVER -eq "nginx") { choco install nginx -y --force }
    if ($WEB_SERVER -eq "apache") { choco install apache-httpd -y --force }
    if ($DATABASE -eq "mariadb") { choco install mariadb -y --force }
    if ($DATABASE -eq "mysql") { choco install mysql -y --force }
    if ($DATABASE -eq "postgresql") { choco install postgresql -y --force }
    if ($DATABASE -eq "sqlite") { choco install sqlite -y --force }

    Success "Packages installed"
}

function Install-WebServer {
    Log "Installing web server: $WEB_SERVER..."
    Show-Progress "Installing web server..." 70

    if ($WEB_SERVER -eq "nginx") {
        Start-Service nginx -ErrorAction SilentlyContinue
        Set-Service -Name nginx -StartupType Automatic
    } elseif ($WEB_SERVER -eq "apache") {
        Start-Service Apache2.4 -ErrorAction SilentlyContinue
        Set-Service -Name Apache2.4 -StartupType Automatic
    } elseif ($WEB_SERVER -eq "litespeed") {
        Warning "LiteSpeed requires manual license installation"
    }
    Success "Web server configured"
}

function Install-Database {
    Log "Configuring database: $DATABASE..."
    Show-Progress "Configuring database..." 85

    if ($DATABASE -eq "mariadb" -or $DATABASE -eq "mysql") {
        Start-Service MySQL -ErrorAction SilentlyContinue
        Start-Service MariaDB -ErrorAction SilentlyContinue
        Set-Service -Name MySQL -StartupType Automatic -ErrorAction SilentlyContinue
        Set-Service -Name MariaDB -StartupType Automatic -ErrorAction SilentlyContinue
    } elseif ($DATABASE -eq "postgresql") {
        Start-Service postgresql* -ErrorAction SilentlyContinue
        Set-Service -Name postgresql* -StartupType Automatic -ErrorAction SilentlyContinue
    }
    Success "Database configured"
}

function Configure-SSL {
    Log "Configuring SSL: $SSL_PROVIDER..."
    Show-Progress "Configuring SSL..." 95

    New-Item -ItemType Directory -Path "$CONFIG_DIR\ssl" -Force | Out-Null

    if ($SSL_PROVIDER -eq "letsencrypt") {
        choco install certbot -y --force -ErrorAction SilentlyContinue
        if ($SSL_EMAIL) {
            certbot certonly --standalone -d $DOMAIN --email $SSL_EMAIL --agree-tos --non-interactive
        } else {
            certbot certonly --standalone -d $DOMAIN --register-unsafely-without-email --agree-tos --non-interactive
        }
        Success "Let's Encrypt SSL configured (Auto-renewal enabled)"
    } elseif ($SSL_PROVIDER -eq "cloudflare") {
        $cert = New-SelfSignedCertificate -DnsName $DOMAIN -CertStoreLocation cert:\LocalMachine\My -KeyAlgorithm RSA -KeyLength 2048
        $certPath = "Cert:\LocalMachine\My\$($cert.Thumbprint)"
        Export-PfxCertificate -Cert $certPath -FilePath "$CONFIG_DIR\ssl\$DOMAIN.pfx" -Password (ConvertTo-SecureString -String "hostingpanel" -Force -AsPlainText) -ErrorAction SilentlyContinue
        Success "Cloudflare SSL configured (Origin certificate)"
    } elseif ($SSL_PROVIDER -eq "http") {
        Warning "Running without SSL"
    }
}

function Configure-WebServer {
    Log "Configuring $WEB_SERVER..."

    $wwwRoot = "C:\inetpub\wwwroot\$DOMAIN"
    New-Item -ItemType Directory -Path $wwwRoot -Force | Out-Null
    Set-Content -Path "$wwwRoot\index.html" -Value "<h1>Hosting Panel - $DOMAIN</h1>"

    if ($WEB_SERVER -eq "nginx") {
        $nginxConf = @"
server {
    listen $WEB_PORT;
    server_name $DOMAIN;
    root $wwwRoot;
    index index.html index.php;
    location / {
        try_files `$uri `$uri/ =404;
    }
}
"@
        Set-Content -Path "C:\tools\nginx-1.24.0\conf\sites-enabled\$DOMAIN.conf" -Value $nginxConf -ErrorAction SilentlyContinue
    } elseif ($WEB_SERVER -eq "apache") {
        $apacheConf = @"
<VirtualHost *:$WEB_PORT>
    ServerName $DOMAIN
    DocumentRoot "$wwwRoot"
    <Directory "$wwwRoot">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
"@
        Set-Content -Path "C:\tools\Apache24\conf\extra\$DOMAIN.conf" -Value $apacheConf -ErrorAction SilentlyContinue
    }
    Success "Web server configured for $DOMAIN"
}

function Save-Config {
    $config = @"
DOMAIN=$DOMAIN
WEB_SERVER=$WEB_SERVER
DATABASE=$DATABASE
SSL_PROVIDER=$SSL_PROVIDER
WEB_PORT=$WEB_PORT
SSL_EMAIL=$SSL_EMAIL
SEC_HTTPS=$SEC_HTTPS
SEC_HSTS=$SEC_HSTS
SEC_TLS=$SEC_TLS
SEC_FRAME=$SEC_FRAME
SEC_XSS=$SEC_XSS
SEC_CSP=$SEC_CSP
CF_SSL_MODE=$CF_SSL_MODE
CF_ALWAYS_HTTPS=$CF_ALWAYS_HTTPS
CF_HTTP3=$CF_HTTP3
CF_BROTLI=$CF_BROTLI
CF_HEADERS=$CF_HEADERS
CF_BOT=$CF_BOT
CF_HOTLINK=$CF_HOTLINK
VERSION=$CURRENT_VERSION
"@
    Set-Content -Path "$CONFIG_DIR\config.env" -Value $config

    # บันทึก REPO และ VERSION ลง config dir
    Set-Content -Path "$CONFIG_DIR\REPO" -Value $GITHUB_REPO
    Set-Content -Path "$CONFIG_DIR\VERSION" -Value $CURRENT_VERSION
}

function Install-HostingCommand {
    Log "Installing hosting management command..."
    $hostingPath = "$INSTALL_DIR\hosting.ps1"
    if (Test-Path $hostingPath) {
        $profileDir = "$env:USERPROFILE\Documents\PowerShell"
        if (-not (Test-Path $profileDir)) { $profileDir = "$env:USERPROFILE\Documents\WindowsPowerShell" }
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

        $aliasLine = "Set-Alias -Name hosting -Value '$hostingPath'"
        $profilePath = "$profileDir\Microsoft.PowerShell_profile.ps1"
        if (-not (Test-Path $profilePath) -or -not (Select-String -Path $profilePath -Pattern "Set-Alias.*hosting" -Quiet)) {
            Add-Content -Path $profilePath -Value $aliasLine
        }

        $batchContent = "@echo off`npowershell -ExecutionPolicy Bypass -File `"$hostingPath`" %*"
        Set-Content -Path "$env:SystemRoot\System32\hosting.bat" -Value $batchContent
    }
    Set-Content -Path "$CONFIG_DIR\version" -Value $CURRENT_VERSION
    Success "Type 'hosting' to manage your panel"
}

function Cleanup-AndExit {
    Error "Installation cancelled"
    Write-Host "${Yellow}Cleaning up...${NC}"
    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# ============================================
# MAIN
# ============================================

function Main {
    Clear-Host
    Write-Host "${Bold}${Cyan}"
    Write-Host "╔══════════════════════════════════════════════════════════════╗"
    Write-Host "║                                                              ║"
    Write-Host "║           WEB HOSTING PANEL INSTALLER                        ║"
    Write-Host "║                        Windows Edition                       ║"
    Write-Host "║                                                              ║"
    Write-Host "╚══════════════════════════════════════════════════════════════╝"
    Write-Host "${NC}"
    Write-Host ""

    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    New-Item -ItemType File -Path $LOG_FILE -Force | Out-Null

    Log "Repository: $GITHUB_REPO"
    Log "Version: $CURRENT_VERSION"

    Check-Admin

    if ($GITHUB_REPO -ne "Phechr-2025/Hosting") {
        $url = Get-LatestRelease
        if ($url) { Download-Source -Url $url }
    } else {
        Warning "Using bundled installation (no custom repo configured)"
    }

    Ask-Domain
    Select-WebServer
    Select-Database
    Select-SSL
    Configure-Security
    if ($SSL_PROVIDER -eq "http") { Select-HttpPort } else { Select-Port }
    Show-Summary

    Log "Starting installation..."
    Write-Host ""

    Install-Packages
    Install-WebServer
    Install-Database
    Configure-SSL
    Configure-WebServer
    Save-Config
    Install-HostingCommand

    Show-Progress "Finalizing installation..." 100

    Write-Host ""
    Write-Host "${Bold}${Green}"
    Write-Host "================================================="
    Write-Host " The script hosting system installation is complete 💯🎉"
    Write-Host "================================================="
    Write-Host "${NC}"
    Write-Host ""
    Write-Host "${Cyan}Access your panel:${NC}"
    if ($SSL_PROVIDER -eq "http") {
        Write-Host "  http://${DOMAIN}:${WEB_PORT}"
    } else {
        Write-Host "  https://${DOMAIN}:${WEB_PORT}"
    }
    Write-Host ""
    Write-Host "${Yellow}Type 'hosting' to open management menu${NC}"
    Write-Host ""
}

Main

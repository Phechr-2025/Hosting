
#Requires -RunAsAdministrator
# ============================================================
# Hosting Control Panel Management Script for Windows
# ============================================================

$CONFIG_DIR = "C:\ProgramData\Hosting-Panel"
$INSTALL_DIR = "C:\Program Files\Hosting-Panel"
$LOG_FILE = "$CONFIG_DIR\hosting.log"

# ============================================
# SINGLE SOURCE OF TRUTH - อ่านจากไฟล์เดียว
# ============================================
if (Test-Path "$CONFIG_DIR\REPO") {
    $GITHUB_REPO = (Get-Content "$CONFIG_DIR\REPO" -Raw).Trim()
} else {
    $GITHUB_REPO = "Phechr-2025/Hosting"
}

if (Test-Path "$CONFIG_DIR\VERSION") {
    $CURRENT_VERSION = (Get-Content "$CONFIG_DIR\VERSION" -Raw).Trim()
} else {
    $CURRENT_VERSION = "v1.0.0"
}

# Load main config
$CONFIG_FILE = "$CONFIG_DIR\config.env"
if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "`e[31mError: Hosting panel not installed or config missing`e[0m"
    exit 1
}

$script:Config = @{}
Get-Content $CONFIG_FILE | ForEach-Object {
    if ($_ -match "^(.+)=(.+)$") {
        $script:Config[$matches[1]] = $matches[2]
    }
}

$script:DOMAIN = $script:Config["DOMAIN"]
$script:WEB_SERVER = $script:Config["WEB_SERVER"]
$script:DATABASE = $script:Config["DATABASE"]
$script:SSL_PROVIDER = $script:Config["SSL_PROVIDER"]
$script:WEB_PORT = $script:Config["WEB_PORT"]

# Colors
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Magenta = "`e[35m"
$NC = "`e[0m"
$Bold = "`e[1m"

# ============================================
# UI FUNCTIONS
# ============================================

function Print-Banner {
    $versionText = "Version $CURRENT_VERSION"
    Write-Host "${Bold}${Cyan}"
    Write-Host "╔══════════════════════════════════════════════════════════════╗"
    Write-Host "║                                                              ║"
    Write-Host "║     ██╗  ██╗ ██████╗ ███████╗████████╗██╗███╗   ██╗███████╗ ║"
    Write-Host "║     ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝ ║"
    Write-Host "║     ███████║██║   ██║███████╗   ██║   ██║██╔██╗ ██║███████╗ ║"
    Write-Host "║     ██╔══██║██║   ██║╚════██║   ██║   ██║██║╚██╗██║╚════██║ ║"
    Write-Host "║     ██║  ██║╚██████╔╝███████║   ██║   ██║██║ ╚████║███████║ ║"
    Write-Host "║     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝ ║"
    Write-Host "║                                                              ║"
    Write-Host "║           HOSTING CONTROL PANEL MANAGEMENT SCRIPT              ║"
    Write-Host "║                        Windows Edition                         ║"
    Write-Host "║                                                              ║"
    $padLeft = [math]::Floor((50 - $versionText.Length) / 2)
    $padRight = 50 - $padLeft - $versionText.Length
    Write-Host ("║" + (" " * $padLeft) + $versionText + (" " * $padRight) + "║")
    Write-Host "╚══════════════════════════════════════════════════════════════╝"
    Write-Host "${NC}"
}

function Print-Menu {
    Write-Host "${Bold}${Yellow}┌─────────────────────────────────────────────────────────────┐${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}1.${NC} Exit Script                                          ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}2.${NC} Update                                               ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}3.${NC} Uninstall                                            ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}4.${NC} Change Domain                                        ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}5.${NC} Change Web Server                                    ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}6.${NC} Change Database                                      ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}7.${NC} Change SSL Provider                                  ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}8.${NC} Change Web Port                                      ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC}  ${Magenta}9.${NC} View Current Settings                                ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC} ${Magenta}10.${NC} Reset Username & Password                            ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC} ${Magenta}11.${NC} Restart the Website                                  ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}│${NC} ${Magenta}12.${NC} Back up Data                                         ${Bold}${Yellow}│${NC}"
    Write-Host "${Bold}${Yellow}└─────────────────────────────────────────────────────────────┘${NC}"
    Write-Host ""
}

# ============================================
# MENU FUNCTIONS
# ============================================

function Cmd-Exit {
    Write-Host "${Green}Exiting...${NC}"
    exit 0
}

function Cmd-Update {
    Write-Host "${Cyan}Checking version...${NC}"
    Write-Host "${Cyan}Repository: $GITHUB_REPO${NC}"
    Write-Host ""

    $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $latestVersion = $release.tag_name
    } catch {
        Write-Host "${Yellow}Cannot check for updates (GitHub API unavailable)${NC}"
        Write-Host "${Yellow}Current Version: $CURRENT_VERSION${NC}"
        return
    }

    Write-Host " Current Version : ${Yellow}$CURRENT_VERSION${NC}"
    Write-Host " Latest Version  : ${Green}$latestVersion${NC}"
    Write-Host ""

    if ($latestVersion -eq $CURRENT_VERSION) {
        Write-Host "${Green}✅ Already up to date ($CURRENT_VERSION)${NC}"
        return
    }

    Write-Host "${Yellow} New version available!${NC}"
    $confirm = Read-Host " Proceed with update? (Y/n)"
    if ($confirm -match "^[Nn]$") { return }

    $confirm2 = Read-Host " Do you confirm that you will proceed with the update? (Y/N)"
    if ($confirm2 -match "^[Nn]$") { return }

    Write-Host "${Cyan}Updating to $latestVersion...${NC}"

    Copy-Item -Path $CONFIG_FILE -Destination "$env:TEMP\hosting-panel-backup.env" -Force

    $zipUrl = "https://github.com/$GITHUB_REPO/archive/refs/tags/$latestVersion.zip"
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile "$tempDir\update.zip" -ErrorAction Stop
        Expand-Archive -Path "$tempDir\update.zip" -DestinationPath $tempDir -Force
        $extracted = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        if ($extracted) {
            Copy-Item -Path "$($extracted.FullName)\*" -Destination $INSTALL_DIR -Recurse -Force
            Copy-Item -Path "$env:TEMP\hosting-panel-backup.env" -Destination $CONFIG_FILE -Force
            Set-Content -Path "$CONFIG_DIR\VERSION" -Value $latestVersion
            Set-Content -Path "$CONFIG_DIR\version" -Value $latestVersion
            $content = Get-Content $CONFIG_FILE
            $content = $content -replace "VERSION=.*", "VERSION=$latestVersion"
            Set-Content -Path $CONFIG_FILE -Value $content
            $script:CURRENT_VERSION = $latestVersion
            Write-Host "${Green}✅ Updated to $latestVersion${NC}"
            Write-Host "${Yellow}Please restart the website (Menu 11)${NC}"
        }
    } catch {
        Write-Host "${Red}❌ Update failed${NC}"
    }

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:TEMP\hosting-panel-backup.env" -Force -ErrorAction SilentlyContinue
}

function Cmd-Uninstall {
    $confirm1 = Read-Host "Should we proceed with the uninstallation? (y/n)"
    if ($confirm1 -match "^[Nn]$") {
        Write-Host "${Yellow}Uninstallation cancelled${NC}"
        return
    }

    $confirm2 = Read-Host "Are you 100% sure to proceed with the uninstallation? (y/n)"
    if ($confirm2 -match "^[Nn]$") {
        Write-Host "${Yellow}Uninstallation cancelled${NC}"
        return
    }

    Write-Host "${Red}Uninstalling hosting panel...${NC}"

    Stop-Service nginx -ErrorAction SilentlyContinue
    Stop-Service Apache2.4 -ErrorAction SilentlyContinue
    Stop-Service MySQL -ErrorAction SilentlyContinue
    Stop-Service MariaDB -ErrorAction SilentlyContinue
    Stop-Service postgresql* -ErrorAction SilentlyContinue

    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\System32\hosting.bat" -Force -ErrorAction SilentlyContinue

    Write-Host "${Green}✅ Hosting panel uninstalled successfully${NC}"
    exit 0
}

function Cmd-ChangeDomain {
    Write-Host "${Cyan}Please enter the domain that points to this server${NC}"
    Write-Host "${Yellow}1. Cancel domain change${NC}"
    Write-Host ""
    $newDomain = Read-Host "Domain"

    if ($newDomain -eq "1") {
        Write-Host "${Yellow}Domain change cancelled${NC}"
        return
    }

    if ([string]::IsNullOrWhiteSpace($newDomain)) {
        Write-Host "${Red}Domain cannot be empty${NC}"
        return
    }

    $serverIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object -First 1).IPAddress
    try {
        $aRecord = [System.Net.Dns]::GetHostAddresses($newDomain) | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1
        $aRecordIp = $aRecord.IPAddressToString
    } catch {
        $aRecordIp = $null
    }

    if ($aRecordIp -ne $serverIp) {
        Write-Host "${Red}❌ Domain does not point to this server${NC}"
        Write-Host "${Red}Expected: $serverIp, Found: $aRecordIp${NC}"
        return
    }

    $oldDomain = $script:DOMAIN
    $content = Get-Content $CONFIG_FILE
    $content = $content -replace "DOMAIN=.*", "DOMAIN=$newDomain"
    Set-Content -Path $CONFIG_FILE -Value $content
    $script:DOMAIN = $newDomain

    Write-Host "${Green}✅ Domain changed to $newDomain${NC}"
}

function Cmd-ChangeWebServer {
    Write-Host "${Bold}Select New Web Server${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Nginx"
    Write-Host "2. Apache"
    Write-Host "3. LiteSpeed"
    Write-Host ""
    Write-Host "${Red}4. Cancel${NC}"
    Write-Host ""

    $choice = Read-Host "Choose [1-4]"
    switch ($choice) {
        "1" { $newServer = "nginx" }
        "2" { $newServer = "apache" }
        "3" { $newServer = "litespeed" }
        "4" { return }
        default { Write-Host "${Red}Invalid choice${NC}"; return }
    }

    if ($newServer -eq $script:WEB_SERVER) {
        Write-Host "${Yellow}Already using $newServer${NC}"
        return
    }

    Stop-Service nginx -ErrorAction SilentlyContinue
    Stop-Service Apache2.4 -ErrorAction SilentlyContinue

    if ($newServer -eq "nginx") { choco install nginx -y --force }
    if ($newServer -eq "apache") { choco install apache-httpd -y --force }

    $content = Get-Content $CONFIG_FILE
    $content = $content -replace "WEB_SERVER=.*", "WEB_SERVER=$newServer"
    Set-Content -Path $CONFIG_FILE -Value $content
    $script:WEB_SERVER = $newServer

    Write-Host "${Green}✅ Web server changed to $newServer${NC}"
    Write-Host "${Yellow}Please restart the website (Menu 11)${NC}"
}

function Cmd-ChangeDatabase {
    Write-Host "${Bold}Select New Database${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. MariaDB"
    Write-Host "2. MySQL"
    Write-Host "3. PostgreSQL"
    Write-Host "4. SQLite"
    Write-Host ""
    Write-Host "${Red}5. Cancel${NC}"
    Write-Host ""

    $choice = Read-Host "Choose [1-5]"
    switch ($choice) {
        "1" { $newDb = "mariadb" }
        "2" { $newDb = "mysql" }
        "3" { $newDb = "postgresql" }
        "4" { $newDb = "sqlite" }
        "5" { return }
        default { Write-Host "${Red}Invalid choice${NC}"; return }
    }

    if ($newDb -eq $script:DATABASE) {
        Write-Host "${Yellow}Already using $newDb${NC}"
        return
    }

    if ($newDb -eq "mariadb") { choco install mariadb -y --force }
    if ($newDb -eq "mysql") { choco install mysql -y --force }
    if ($newDb -eq "postgresql") { choco install postgresql -y --force }
    if ($newDb -eq "sqlite") { choco install sqlite -y --force }

    $content = Get-Content $CONFIG_FILE
    $content = $content -replace "DATABASE=.*", "DATABASE=$newDb"
    Set-Content -Path $CONFIG_FILE -Value $content
    $script:DATABASE = $newDb

    Write-Host "${Green}✅ Database changed to $newDb${NC}"
}

function Cmd-ChangeSSL {
    Write-Host "${Bold}Select New SSL Provider${NC}"
    Write-Host "────────────────────────"
    Write-Host "1. Let's Encrypt"
    Write-Host "2. Cloudflare SSL"
    Write-Host "3. HTTP Only"
    Write-Host ""
    Write-Host "${Red}4. Cancel${NC}"
    Write-Host ""

    $choice = Read-Host "Choose [1-4]"
    switch ($choice) {
        "1" { $newSsl = "letsencrypt" }
        "2" { $newSsl = "cloudflare" }
        "3" { $newSsl = "http" }
        "4" { return }
        default { Write-Host "${Red}Invalid choice${NC}"; return }
    }

    if ($newSsl -eq $script:SSL_PROVIDER) {
        Write-Host "${Yellow}Already using $newSsl${NC}"
        return
    }

    $content = Get-Content $CONFIG_FILE
    $content = $content -replace "SSL_PROVIDER=.*", "SSL_PROVIDER=$newSsl"
    Set-Content -Path $CONFIG_FILE -Value $content
    $script:SSL_PROVIDER = $newSsl

    Write-Host "${Green}✅ SSL provider changed to $newSsl${NC}"
    Write-Host "${Yellow}Please restart the website (Menu 11)${NC}"
}

function Cmd-ChangePort {
    $newPort = Read-Host "Enter new web port"
    if ($newPort -notmatch "^\d+$") {
        Write-Host "${Red}Invalid port${NC}"
        return
    }

    $inUse = Get-NetTCPConnection -LocalPort ([int]$newPort) -ErrorAction SilentlyContinue
    if ($inUse) {
        Write-Host "${Red}Port $newPort is already in use${NC}"
        return
    }

    $content = Get-Content $CONFIG_FILE
    $content = $content -replace "WEB_PORT=.*", "WEB_PORT=$newPort"
    Set-Content -Path $CONFIG_FILE -Value $content
    $script:WEB_PORT = $newPort

    Write-Host "${Green}✅ Web port changed to $newPort${NC}"
    Write-Host "${Yellow}Please restart the website (Menu 11)${NC}"
}

function Cmd-ViewSettings {
    Write-Host ""
    Write-Host "${Bold}${Cyan}─────────────────────────────${NC}"
    Write-Host "${Bold}${Cyan}    Current Settings${NC}"
    Write-Host "${Bold}${Cyan}─────────────────────────────${NC}"
    Write-Host " Repository   : ${Green}$GITHUB_REPO${NC}"
    Write-Host " Domain       : ${Green}$($script:DOMAIN)${NC}"
    Write-Host " Web Server   : ${Green}$($script:WEB_SERVER)${NC}"
    Write-Host " Database     : ${Green}$($script:DATABASE)${NC}"
    Write-Host " SSL Provider : ${Green}$($script:SSL_PROVIDER)${NC}"
    Write-Host " Web Port     : ${Green}$($script:WEB_PORT)${NC}"
    Write-Host " Panel Version: ${Green}$CURRENT_VERSION${NC}"
    Write-Host "${Bold}${Cyan}─────────────────────────────${NC}"
    Write-Host ""
}

function Cmd-ResetCredentials {
    Write-Host "${Cyan}Reset Username & Password${NC}"
    Write-Host ""
    $newUser = Read-Host "Enter new username"
    $newPass = Read-Host "Enter new password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    if ([string]::IsNullOrWhiteSpace($newUser) -or [string]::IsNullOrWhiteSpace($plainPass)) {
        Write-Host "${Red}Username and password cannot be empty${NC}"
        return
    }

    $credString = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($newUser)) + ":" + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($plainPass))
    Set-Content -Path "$CONFIG_DIR\.htpasswd" -Value $credString

    Write-Host "${Green}✅ Credentials updated${NC}"
}

function Cmd-Restart {
    Write-Host "${Cyan}Restarting website services...${NC}"

    if ($script:WEB_SERVER -eq "nginx") {
        Restart-Service nginx -ErrorAction SilentlyContinue
    } elseif ($script:WEB_SERVER -eq "apache") {
        Restart-Service Apache2.4 -ErrorAction SilentlyContinue
    }

    if ($script:DATABASE -eq "mariadb" -or $script:DATABASE -eq "mysql") {
        Restart-Service MySQL -ErrorAction SilentlyContinue
        Restart-Service MariaDB -ErrorAction SilentlyContinue
    } elseif ($script:DATABASE -eq "postgresql") {
        Restart-Service postgresql* -ErrorAction SilentlyContinue
    }

    Write-Host "${Green}✅ Services restarted${NC}"
}

function Cmd-Backup {
    $backupDir = "C:\ProgramData\Hosting-Panel\Backups"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$backupDir\backup_${timestamp}.zip"

    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    Write-Host "${Cyan}Creating backup...${NC}"

    Compress-Archive -Path $CONFIG_DIR, $INSTALL_DIR, "C:\inetpub\wwwroot" -DestinationPath $backupFile -ErrorAction SilentlyContinue

    if (Test-Path $backupFile) {
        Write-Host "${Green}✅ Backup created: $backupFile${NC}"
    } else {
        Write-Host "${Red}❌ Backup failed${NC}"
    }
}

# ============================================
# MAIN LOOP
# ============================================

function Main {
    while ($true) {
        Clear-Host
        Print-Banner
        Print-Menu

        $choice = Read-Host "Select option [1-12]"

        switch ($choice) {
            "1" { Cmd-Exit }
            "2" { Cmd-Update }
            "3" { Cmd-Uninstall }
            "4" { Cmd-ChangeDomain }
            "5" { Cmd-ChangeWebServer }
            "6" { Cmd-ChangeDatabase }
            "7" { Cmd-ChangeSSL }
            "8" { Cmd-ChangePort }
            "9" { Cmd-ViewSettings }
            "10" { Cmd-ResetCredentials }
            "11" { Cmd-Restart }
            "12" { Cmd-Backup }
            default { Write-Host "${Red}Invalid option${NC}" }
        }

        Write-Host ""
        Read-Host "Press Enter to continue..."
    }
}

Main

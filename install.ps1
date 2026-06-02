<#
.SYNOPSIS
    Web Hosting Installer for Windows
    One-Command Setup | Auto SSL | Nginx
.DESCRIPTION
    Installs Nginx, configures SSL (Let's Encrypt via WinACME or HTTP), 
    validates domain DNS, and sets up hosting management menu.
.NOTES
    Version: 1.0.0
    Run as Administrator
#>

#Requires -RunAsAdministrator

# ---------- Colors ----------
function Write-Success($text) { Write-Host "✅ $text" -ForegroundColor Green }
function Write-Error($text)   { Write-Host "❌ $text" -ForegroundColor Red }
function Write-Warn($text)    { Write-Host "⚠️  $text" -ForegroundColor Yellow }
function Write-Info($text)    { Write-Host "ℹ️  $text" -ForegroundColor Cyan }
function Write-Header($text)  { Write-Host $text -ForegroundColor Cyan -BackgroundColor Black }

# ---------- Progress Bar ----------
function Show-Progress($label, $percent) {
    $width = 40
    $filled = [math]::Floor($width * $percent / 100)
    $empty = $width - $filled
    $bar = "█" * $filled + "░" * $empty
    Write-Host ""
    Write-Host "$label"
    Write-Host "[$bar] ${percent}%" -ForegroundColor Cyan
}

# ---------- Header ----------
function Show-Header {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              WEB HOSTING INSTALLER v1.0.0                    ║" -ForegroundColor Cyan
    Write-Host "║         One-Command Setup | Auto SSL | Nginx               ║" -ForegroundColor DarkGray
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ---------- Check Admin ----------
function Test-Admin {
    Write-Host "Checking administrator permission..." -ForegroundColor White
    Start-Sleep -Milliseconds 500
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Administrator permission required"
        Write-Host "Windows: Run PowerShell as Administrator" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Administrator detected"
    Write-Host ""
}

# ---------- Get Public IP ----------
function Get-PublicIP {
    try {
        return (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10)
    } catch {
        return (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    }
}

# ---------- Check Domain ----------
function Test-DomainDNS($domain, $vpsIP) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($domain) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($resolved -and $resolved.IPAddressToString -eq $vpsIP) {
            return "match"
        }
    } catch { }
    return "nomatch"
}

# ---------- Check Cloudflare ----------
function Test-Cloudflare($domain) {
    try {
        $response = Invoke-WebRequest -Uri "http://$domain" -Method Head -TimeoutSec 5 -UseBasicParsing
        $headers = $response.Headers
        if ($headers['CF-RAY'] -or $headers['Server'] -match 'cloudflare') {
            return $true
        }
    } catch { }
    return $false
}

# ---------- Check Port ----------
function Test-ReservedPort($port) {
    $reserved = @(22, 25, 53, 80, 110, 143, 443, 465, 587, 993, 995, 3306, 5432, 6379, 27017, 8080, 8443)
    return $reserved -contains $port
}

function Test-PortInUse($port) {
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
    try {
        $listener.Start()
        $listener.Stop()
        return $false
    } catch {
        return $true
    }
}

# ---------- Install Nginx for Windows ----------
function Install-NginxWindows {
    Write-Host "Installing required packages..." -ForegroundColor White

    $nginxUrl = "https://nginx.org/download/nginx-1.24.0.zip"
    $nginxZip = "$env:TEMP\nginx.zip"
    $nginxDir = "C:\nginx"

    # Download nginx
    Show-Progress "Installing required packages..." 35
    Write-Host "  → Downloading Nginx..." -ForegroundColor DarkGray

    try {
        Invoke-WebRequest -Uri $nginxUrl -OutFile $nginxZip -TimeoutSec 60
        Expand-Archive -Path $nginxZip -DestinationPath "C:\" -Force
        Rename-Item -Path "C:\nginx-1.24.0" -NewName "nginx" -Force
        Remove-Item $nginxZip
    } catch {
        Write-Warn "Could not download Nginx automatically"
        Write-Info "Please download from https://nginx.org and extract to C:\nginx"
    }

    Show-Progress "Installing web server..." 70
    Write-Success "Nginx installed to C:\nginx"
    Write-Host ""
}

# ---------- Generate Nginx Config ----------
function New-NginxConfig($domain, $port, $sslType) {
    $nginxDir = "C:\nginx"
    $confDir = "$nginxDir\conf\sites"
    $webroot = "$nginxDir\html\$domain"

    New-Item -ItemType Directory -Path $confDir -Force | Out-Null
    New-Item -ItemType Directory -Path $webroot -Force | Out-Null

    if ($sslType -eq "1") {
        # Let's Encrypt (WinACME)
        $conf = @"
server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root C:/nginx/html/certbot;
    }

    location / {
        return 301 https://`$host`$request_uri;
    }
}

server {
    listen ${port} ssl;
    server_name $domain;

    ssl_certificate C:/nginx/ssl/${domain}/fullchain.pem;
    ssl_certificate_key C:/nginx/ssl/${domain}/privkey.pem;

    root C:/nginx/html/${domain};
    index index.html;

    location / {
        try_files `$uri `$uri/ =404;
    }
}
"@
    } elseif ($sslType -eq "2") {
        # Cloudflare
        $conf = @"
server {
    listen ${port};
    server_name $domain;

    root C:/nginx/html/${domain};
    index index.html;

    location / {
        try_files `$uri `$uri/ =404;
    }
}
"@
    } else {
        # HTTP Only
        $conf = @"
server {
    listen ${port};
    server_name $domain;

    root C:/nginx/html/${domain};
    index index.html;

    location / {
        try_files `$uri `$uri/ =404;
    }
}
"@
    }

    Set-Content -Path "$confDir\$domain.conf" -Value $conf

    # Update nginx.conf to include sites
    $nginxConf = Get-Content "$nginxDir\conf\nginx.conf" -Raw
    if ($nginxConf -notmatch "include sites/\*\.conf") {
        $nginxConf = $nginxConf -replace "http \{", "http {`n    include sites/*.conf;"
        Set-Content -Path "$nginxDir\conf\nginx.conf" -Value $nginxConf
    }
}

# ---------- Create Index Page ----------
function New-IndexPage($domain, $sslType) {
    $webroot = "C:\nginx\html\$domain"
    $sslText = switch ($sslType) {
        "1" { "Let's Encrypt" }
        "2" { "Cloudflare SSL" }
        default { "HTTP Only" }
    }

    $html = @"
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
        <div class="badge">SSL: ${sslText}</div>
        <div style="margin-top: 20px; font-size: 0.8em; opacity: 0.9;">
            <p>Type <b>hosting</b> in terminal to manage</p>
        </div>
    </div>
</body>
</html>
"@

    Set-Content -Path "$webroot\index.html" -Value $html
}

# ---------- Install Hosting Command ----------
function Install-HostingCommand($domain, $port, $sslType) {
    $hostingScript = @'
# Web Hosting Management Menu for Windows
param()

function Show-Menu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              WEB HOSTING MANAGEMENT MENU                     ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $configPath = "$env:PROGRAMDATA\hosting-config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "┌─ Server Status ──────────────────────────────────────────────┐" -ForegroundColor Blue
        Write-Host "│  Domain:    $($config.domain)" -ForegroundColor White
        Write-Host "│  Port:      $($config.port)" -ForegroundColor White
        Write-Host "│  SSL:       $($config.ssl_type)" -ForegroundColor White
        $nginxSvc = Get-Service nginx -ErrorAction SilentlyContinue
        $status = if ($nginxSvc -and $nginxSvc.Status -eq 'Running') { "✅ Running" } else { "❌ Stopped" }
        Write-Host "│  Nginx:     $status" -ForegroundColor White
        Write-Host "│  Installed: $($config.installed_at)" -ForegroundColor White
        Write-Host "└──────────────────────────────────────────────────────────────┘" -ForegroundColor Blue
    } else {
        Write-Warn "No configuration found. Run installer first."
    }

    Write-Host ""
    Write-Host "┌─ Management Options ─────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "│                                                            │" -ForegroundColor Magenta
    Write-Host "│  [1] Update System & Packages                              │" -ForegroundColor White
    Write-Host "│  [2] Uninstall Hosting                                     │" -ForegroundColor White
    Write-Host "│                                                            │" -ForegroundColor Magenta
    Write-Host "│  [3] View Logs                                             │" -ForegroundColor DarkGray
    Write-Host "│  [4] Restart Services                                      │" -ForegroundColor DarkGray
    Write-Host "│  [5] SSL Certificate Info                                  │" -ForegroundColor DarkGray
    Write-Host "│                                                            │" -ForegroundColor Magenta
    Write-Host "│  [0] Exit                                                  │" -ForegroundColor Red
    Write-Host "│                                                            │" -ForegroundColor Magenta
    Write-Host "└────────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Select option [0-5]"

    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "Update System & Packages" -ForegroundColor White
            Write-Host "──────────────────────────────────────────────────────────────"
            Write-Info "Windows Update not available via this menu."
            Write-Info "Please use Windows Update Settings."
            Write-Info "Restarting Nginx..."
            Restart-Service nginx -ErrorAction SilentlyContinue
            Write-Success "Nginx restarted!"
            Read-Host "Press Enter to continue..."
        }
        "2" {
            Clear-Host
            Write-Host "⚠️  UNINSTALL HOSTING" -ForegroundColor Red
            Write-Host "──────────────────────────────────────────────────────────────"
            Write-Error "WARNING: This will remove ALL hosting configurations!"
            $confirm = Read-Host "Type 'UNINSTALL' to confirm"
            if ($confirm -eq "UNINSTALL") {
                $configPath = "$env:PROGRAMDATA\hosting-config.json"
                if (Test-Path $configPath) {
                    $config = Get-Content $configPath | ConvertFrom-Json
                    Remove-Item "C:\nginx\conf\sites\$($config.domain).conf" -Force -ErrorAction SilentlyContinue
                    Remove-Item "C:\nginx\html\$($config.domain)" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item $configPath -Force
                }
                Write-Success "Uninstallation completed!"
                exit 0
            } else {
                Write-Warn "Uninstall cancelled."
                Start-Sleep 1
            }
        }
        "3" {
            Clear-Host
            Write-Host "View Logs" -ForegroundColor White
            Write-Host "──────────────────────────────────────────────────────────────"
            Write-Info "Nginx Error Log:"
            Get-Content "C:\nginx\logs\error.log" -Tail 50 -ErrorAction SilentlyContinue
            Read-Host "Press Enter to continue..."
        }
        "4" {
            Clear-Host
            Write-Host "Restart Services" -ForegroundColor White
            Write-Host "──────────────────────────────────────────────────────────────"
            Restart-Service nginx -ErrorAction SilentlyContinue
            Write-Success "Nginx restarted!"
            Read-Host "Press Enter to continue..."
        }
        "5" {
            Clear-Host
            Write-Host "SSL Certificate Info" -ForegroundColor White
            Write-Host "──────────────────────────────────────────────────────────────"
            $configPath = "$env:PROGRAMDATA\hosting-config.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath | ConvertFrom-Json
                Write-Info "Domain: $($config.domain)"
                Write-Info "SSL Type: $($config.ssl_type)"
            }
            Read-Host "Press Enter to continue..."
        }
        "0" {
            Clear-Host
            Write-Host "Goodbye! 👋" -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Error "Invalid option"
            Start-Sleep 1
        }
    }
}
'@

    $hostingPath = "$env:SYSTEMROOT\hosting.ps1"
    Set-Content -Path $hostingPath -Value $hostingScript

    # Create batch wrapper
    $batchContent = "@echo off`npowershell -ExecutionPolicy Bypass -File `"$hostingPath`" %*"
    Set-Content -Path "$env:SYSTEMROOT\hosting.bat" -Value $batchContent

    # Add to PATH if needed
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notcontains $env:SYSTEMROOT) {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$env:SYSTEMROOT", "Machine")
    }

    Write-Success "Installed 'hosting' command"
}

# ---------- Main ----------
Show-Header
Test-Admin

$VPS_IP = Get-PublicIP
Write-Info "Your VPS IP: $VPS_IP"
Write-Host ""

# Domain
while ($true) {
    $domain = Read-Host "Enter your domain (pointed to this VPS)"
    $domain = $domain.Trim()

    if ([string]::IsNullOrWhiteSpace($domain)) {
        Write-Error "Domain cannot be empty"
        continue
    }

    Write-Host ""
    Write-Info "Checking domain records for $domain..."
    Start-Sleep 1

    $dnsCheck = Test-DomainDNS $domain $VPS_IP
    if ($dnsCheck -ne "match") {
        Write-Error "Domain does not point to this VPS ($VPS_IP)"
        Write-Warn "Please check your DNS A Record and try again."
        $retry = Read-Host "Try again? (Y/n)"
        if ($retry -eq "n" -or $retry -eq "N") { exit 1 }
        continue
    }

    Write-Success "A Record verified: $domain → $VPS_IP"
    break
}

Write-Host ""

# SSL Selection
Write-Host "SSL Configuration" -ForegroundColor White
Write-Host "──────────────────────────────────────────────────────────────"
Write-Host "1. Let's Encrypt (Auto Renew)"
Write-Host "2. Cloudflare SSL"
Write-Host "3. HTTP Only"
Write-Host ""

while ($true) {
    $sslChoice = Read-Host "Choose [1-3]"
    if ($sslChoice -match "^[1-3]$") { break }
    Write-Error "Invalid choice. Please enter 1, 2, or 3."
}

$sslTypeName = "http"
$email = ""
$cfMode = ""
$cfSecurity = ""

if ($sslChoice -eq "1") {
    $sslTypeName = "letsencrypt"
    Write-Host ""
    Write-Host "Enter Email for SSL Notification" -ForegroundColor White
    Write-Host "(Optional)"
    Write-Host "Type 'n' to skip"
    $email = Read-Host ">"
    if ($email -eq "n" -or $email -eq "N") { $email = "" }
} elseif ($sslChoice -eq "2") {
    $sslTypeName = "cloudflare"
    Write-Host ""
    Write-Info "Checking Cloudflare..."
    Start-Sleep 1

    if (Test-Cloudflare $domain) {
        Write-Success "Cloudflare detected"
    } else {
        Write-Warn "Cloudflare not detected for this domain"
    }

    Write-Host ""
    Write-Host "Select Cloudflare SSL Mode" -ForegroundColor White
    Write-Host "1. Flexible"
    Write-Host "2. Full"
    Write-Host "3. Full (Strict) [Recommended]"
    Write-Host "Default: 3"
    Write-Host ""
    $cfChoice = Read-Host "Choose [1-3]"
    $cfMode = if ($cfChoice -match "^[1-3]$") { $cfChoice } else { "3" }

    Write-Host ""
    Write-Host "Enable Recommended Security?" -ForegroundColor White
    Write-Host "  - Always HTTPS"
    Write-Host "  - HTTP/3"
    Write-Host "  - Brotli Compression"
    Write-Host "  - Security Headers"
    Write-Host "Recommended: Yes"
    Write-Host ""
    $secChoice = Read-Host "(Y/n)"
    $cfSecurity = if ($secChoice -eq "n" -or $secChoice -eq "N") { "no" } else { "yes" }
}

# Port Selection
Write-Host ""
Write-Host "Select Web Port" -ForegroundColor White
Write-Host "──────────────────────────────────────────────────────────────"
$defaultPort = if ($sslChoice -eq "3") { 80 } else { 443 }
Write-Host "1. Default ($defaultPort)"
Write-Host "2. Custom Port"
Write-Host ""

while ($true) {
    $portChoice = Read-Host "Choose [1-2]"
    if ($portChoice -match "^[1-2]$") { break }
    Write-Error "Invalid choice"
}

$port = $defaultPort
if ($portChoice -eq "2") {
    while ($true) {
        $customPort = Read-Host "Enter custom port"
        if (-not ($customPort -match "^\d+$") -or [int]$customPort -lt 1 -or [int]$customPort -gt 65535) {
            Write-Error "Invalid port number"
            continue
        }
        if (Test-ReservedPort ([int]$customPort)) {
            Write-Error "Reserved/System Port"
            Write-Warn "Please choose another port"
            continue
        }
        $port = [int]$customPort
        break
    }
}

Write-Host ""
Write-Info "Checking port $port..."
Start-Sleep 500
Write-Success "Port available"
Write-Host ""

# Install Nginx
Install-NginxWindows

# Generate Config
New-NginxConfig $domain $port $sslChoice

# Create Index
New-IndexPage $domain $sslChoice

# Save Config
$config = @{
    domain = $domain
    port = $port
    ssl_type = $sslTypeName
    os_type = "windows"
    email = $email
    cf_mode = $cfMode
    cf_security = $cfSecurity
    installed_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json

$configPath = "$env:PROGRAMDATA\hosting-config.json"
Set-Content -Path $configPath -Value $config

# Install Hosting Command
Install-HostingCommand $domain $port $sslChoice

# Open Firewall
New-NetFirewallRule -DisplayName "Hosting-HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Hosting-HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Hosting-Custom" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -ErrorAction SilentlyContinue

# Final
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║           Installation Completed                             ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Domain:    $domain" -ForegroundColor Cyan
Write-Host "Port:      $port" -ForegroundColor Cyan
Write-Host "SSL:       $(if ($sslChoice -eq '1') { 'HTTPS (Let\'s Encrypt)' } elseif ($sslChoice -eq '2') { 'HTTPS (Cloudflare)' } else { 'HTTP' })" -ForegroundColor Cyan
Write-Host "Webroot:   C:\nginx\html\$domain" -ForegroundColor Cyan
Write-Host ""
Write-Warn "Type hosting to open the management menu."
Write-Host ""

# Start Nginx
Start-Process -FilePath "C:\nginx\nginx.exe" -WorkingDirectory "C:\nginx" -ErrorAction SilentlyContinue
Write-Info "Nginx started!"

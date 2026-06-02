# 🌐 Web Hosting Installer 

ระบบติดตั้ง Web Hosting รองรับทุกอุปกรณ์

## ✨ ฟีเจอร์หลัก

- ✅ **One-Command Install** - ติดตั้งด้วยคำสั่งเดียว
- ✅ **TUI Interface** - เมนูสวยงามใน Terminal
- ✅ **Auto Detect OS** - รองรับ Ubuntu, Debian, CentOS, Rocky, Fedora, Arch, Windows
- ✅ **Progress Bar** - แสดง % การติดตั้งแบบ Real-time
- ✅ **Domain Validation** - ตรวจสอบ DNS A/AAAA Record อัตโนมัติ
- ✅ **SSL 3 โหมด** - Let's Encrypt | Cloudflare | HTTP Only
- ✅ **Auto SSL Renew** - ต่ออายุ SSL อัตโนมัติ
- ✅ **Reserved Port Protection** - ป้องกันการใช้ Port ระบบ
- ✅ **Management Menu** - พิมพ์ `hosting` เพื่อจัดการหลังติดตั้ง
- ✅ **Update & Uninstall** - อัปเดต/ถอนการติดตั้งผ่านเมนู

## 🚀 วิธีติดตั้ง (One-Liner)

### Linux (Ubuntu / Debian / CentOS / Rocky / Fedora / Arch)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.sh)
```

หรือใช้ `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.sh)
```

### Windows (PowerShell Administrator)

```powershell
irm https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.ps1 | iex
```

หรือดาวน์โหลด ZIP แล้วรัน:

```powershell
# เปิด PowerShell แบบ Administrator
.\install.ps1
```

## 📋 ความต้องการของระบบ

| OS | สิทธิ์ | เครื่องมือ |
|----|--------|-----------|
| Linux | Root / sudo | bash, curl/wget |
| Windows | Administrator | PowerShell 5.1+ |

## 🖥️ ขั้นตอนการติดตั้ง

```
╔══════════════════════════════════════════════════════════════╗
║              WEB HOSTING INSTALLER v1.0.0                    ║
║         One-Command Setup | Auto SSL | Nginx               ║
╚══════════════════════════════════════════════════════════════╝

Checking administrator permission...
✅ Root/Administrator detected

Installing required packages...
[█████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 35%

Installing web server...
[██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 70%

Domain Configuration
──────────────────────────────────────────────────────────────
ℹ️  Your VPS IP: 192.168.1.100

Enter your domain (pointed to this VPS): example.com

Checking domain records for example.com...
✅ A Record verified: example.com → 192.168.1.100

SSL Configuration
──────────────────────────────────────────────────────────────
1. Let's Encrypt (Auto Renew)
2. Cloudflare SSL
3. HTTP Only

Choose [1-3]: 1

Enter Email for SSL Notification
(Optional)
Type 'n' to skip
> admin@example.com

Select Web Port
──────────────────────────────────────────────────────────────
1. Default (443)
2. Custom Port

Choose [1-2]: 1

Checking port 443...
✅ Port available

Configuring SSL...
[██████████████████████████████████████████] 100%

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           Installation Completed                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

Domain:    example.com
Port:      443
SSL:       HTTPS (Let's Encrypt)
Webroot:   /var/www/example.com

Type hosting to open the management menu.
```

## 🎛️ เมนูจัดการ (`hosting`)

หลังติดตั้งเสร็จ พิมพ์คำสั่ง `hosting` ใน Terminal:

```
╔══════════════════════════════════════════════════════════════╗
║              WEB HOSTING MANAGEMENT MENU                     ║
╚══════════════════════════════════════════════════════════════╝

┌─ Server Status ──────────────────────────────────────────────┐
│  Domain:    example.com                                    │
│  Port:      443                                            │
│  SSL:       letsencrypt                                    │
│  Nginx:     ✅ Running                                     │
│  Installed: 2026-06-02 14:30:00                            │
└──────────────────────────────────────────────────────────────┘

┌─ Management Options ─────────────────────────────────────────┐
│                                                            │
│  [1] Update System & Packages                              │
│  [2] Uninstall Hosting                                     │
│                                                            │
│  [3] View Logs                                             │
│  [4] Restart Services                                      │
│  [5] SSL Certificate Info                                  │
│                                                            │
│  [0] Exit                                                  │
│                                                            │
└────────────────────────────────────────────────────────────┘

Select option [0-5]:
```

### ตัวเลือกเมนู

| ตัวเลือก | คำอธิบาย |
|---------|---------|
| **1. Update** | อัปเดตแพ็กเกจระบบ, อัปเกรด certbot, รีสตาร์ท nginx |
| **2. Uninstall** | ถอนการติดตั้งทั้งหมด (ต้องพิมพ์ `UNINSTALL` เพื่อยืนยัน) |
| **3. View Logs** | ดู Nginx Error/Access Logs |
| **4. Restart Services** | รีสตาร์ทบริการ nginx |
| **5. SSL Info** | ดูข้อมูลใบรับรอง SSL และวันหมดอายุ |
| **0. Exit** | ออกจากเมนู |

## 🔒 ระบบป้องกัน Port

Port ต่อไปนี้ถูกบล็อกเพื่อความปลอดภัย:

```
❌ Reserved/System Port
Please choose another port
```

| Port | บริการ |
|------|--------|
| 22 | SSH |
| 25 | SMTP |
| 53 | DNS |
| 80 | HTTP (default) |
| 443 | HTTPS (default) |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 27017 | MongoDB |

## 🌐 การตั้งค่า Cloudflare SSL

เมื่อเลือก **Cloudflare SSL**:

1. ระบบตรวจสอบว่าใช้ Cloudflare NS หรือไม่
2. ตรวจสอบว่าเปิด **Orange Cloud Proxy** หรือไม่
   ```
   ❌ Proxy is disabled
   Please enable Orange Cloud Proxy and try again.
   ```
3. เลือก SSL Mode:
   - **Flexible** - เข้ารหัสระหว่างผู้ใช้กับ Cloudflare
   - **Full** - เข้ารหัสทั้งหมด ไม่ตรวจสอบใบรับรองบนเซิร์ฟเวอร์
   - **Full (Strict)** [แนะนำ] - เข้ารหัสทั้งหมด + ตรวจสอบใบรับรอง

4. เลือกเปิดใช้งานความปลอดภัยแนะนำ:
   - Always HTTPS
   - HTTP/3
   - Brotli Compression
   - Security Headers

## 🔄 การต่ออายุ SSL อัตโนมัติ

### Let's Encrypt
- ตั้งค่า Cron Job อัตโนมัติ: `0 0,12 * * *`
- ตรวจสอบและต่ออายุทุก 12 ชั่วโมง
- ไม่ต้องทำอะไรเพิ่ม!

### Cloudflare
- จัดการผ่าน Cloudflare Dashboard
- ไม่ต้องต่ออายุบนเซิร์ฟเวอร์

## 📁 โครงสร้างไฟล์

```
hosting-installer/
├── install.sh          # สคริปต์หลักสำหรับ Linux (One-Liner)
├── install.ps1         # สคริปต์หลักสำหรับ Windows
├── README.md           # คู่มือการใช้งาน (ไฟล์นี้)
└── LICENSE             # MIT License
```

## 🛠️ การแก้ไขปัญหา

### ไม่มีสิทธิ์ Root/Admin
```
❌ Administrator permission required
Linux: Use sudo
Windows: Run PowerShell as Administrator
```

### โดเมนไม่ชี้มายัง VPS
```
❌ Domain does not point to this VPS (xxx.xxx.xxx.xxx)
Please check your DNS A Record and try again.
```

### Cloudflare Proxy ปิด
```
❌ Proxy is disabled
Please enable Orange Cloud Proxy and try again.
```

## 📄 License

MIT License - ใช้งานได้ฟรี

---

**สร้างด้วย ❤️ สำหรับนักพัฒนาและผู้ดูแลเซิร์ฟเวอร์**

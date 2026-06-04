# 🚀 Hosting Panel System

ระบบจัดการ Web Hosting Panel แบบ One-Command Installation รองรับทั้ง Linux และ Windows

## 📋 คุณสมบัติหลัก

- ✅ ติดตั้งด้วยคำสั่งเดียว (One-Command Install)
- ✅ รองรับ Linux: Ubuntu, CentOS, Rocky Linux, AlmaLinux, Fedora, Debian
- ✅ รองรับ Windows: Windows 10/11, Windows Server (PowerShell)
- ✅ แสดง Progress Bar แบบ Real-time ระหว่างติดตั้ง
- ✅ ตรวจสอบสิทธิ์ Root/Administrator อัตโนมัติ
- ✅ ตรวจสอบ DNS A Record / AAAA Record ก่อนติดตั้ง
- ✅ เลือก Web Server ได้: Nginx, Apache, LiteSpeed
- ✅ เลือก Database ได้: MariaDB, MySQL, PostgreSQL, SQLite
- ✅ รองรับ SSL หลายรูปแบบ: Let's Encrypt, Cloudflare SSL, HTTP Only
- ✅ ต่ออายุ SSL อัตโนมัติ (Let's Encrypt & Cloudflare)
- ✅ ตรวจสอบ Port ซ้ำ / System Port อัตโนมัติ
- ✅ ระบบ Security Headers ครบถ้วน (HSTS, CSP, XSS, Frame, TLS)
- ✅ เมนูจัดการหลังติดตั้ง (`hosting` command)
- ✅ ระบบอัปเดตอัตโนมัติจาก GitHub Releases
- ✅ ระบบสำรองข้อมูล (Backup)
- ✅ ระบบถอนการติดตั้งพร้อมยืนยัน 2 ชั้น
- ✅ **ระบบ REPO/VERSION ศูนย์กลาง - แก้ไฟล์เดียวจบทุกสคริปต์**

## 🎯 ระบบ REPO/VERSION ศูนย์กลาง

แก้ไขค่าเพียง **2 ไฟล์** ใน root ของโปรเจกต์ แล้วทุกสคริปต์จะอ่านค่าอัตโนมัติ:

| ไฟล์ | ใช้เก็บ | ตัวอย่าง |
|------|---------|---------|
| `REPO` | GitHub Repository | `Phechr-2025/Hosting` |
| `VERSION` | เวอร์ชันปัจจุบัน | `v1.0.0` |

### วิธีใช้งาน

1. แก้ไขไฟล์ `REPO` ถ้าต้องการเปลี่ยน repository
2. แก้ไขไฟล์ `VERSION` ถ้าต้องการเปลี่ยนเวอร์ชันเริ่มต้น
3. ทุกสคริปต์ (`install.sh`, `install.ps1`, `hosting.sh`, `hosting.ps1`) จะอ่านค่าจากไฟล์นี้อัตโนมัติ

> 💡 **Tip:** ถ้ารันผ่าน `curl`/`wget` ไฟล์ `REPO`/`VERSION` จะไม่อยู่ด้วย สคริปต์จะใช้ค่า fallback ที่ตั้งไว้ แต่หลังติดตั้งจะบันทึกลงระบบและเมนู `hosting` จะอ่านจากที่บันทึก

## 🖥️ การติดตั้งบน Linux

### คำสั่งติดตั้ง (One-Command)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.sh)
```

หรือ

```bash
wget -qO- https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.sh | bash
```

### ขั้นตอนการติดตั้ง

1. ตรวจสอบสิทธิ์ Root
2. ดึง Source Code จาก GitHub Releases ล่าสุด
3. กรอกโดเมนที่ชี้มายัง VPS (ตรวจสอบ A/AAAA Record)
4. เลือก Web Server (Nginx/Apache/LiteSpeed)
5. เลือก Database (MariaDB/MySQL/PostgreSQL/SQLite)
6. เลือก SSL Provider (Let's Encrypt/Cloudflare/HTTP)
7. ตั้งค่า Security Headers
8. เลือก Port (ตรวจสอบอัตโนมัติ)
9. ยืนยันการติดตั้ง
10. รอระบบติดตั้งอัตโนมัติ พร้อมแสดง Progress Bar

## 🪟 การติดตั้งบน Windows

### คำสั่งติดตั้ง (PowerShell แบบ Administrator)

```powershell
powershell -Command "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Phechr-2025/Hosting/main/install.ps1'))"
```

หรือดาวน์โหลด `install.ps1` แล้วรัน:

```powershell
.\install.ps1
```

> ⚠️ ต้องรัน PowerShell ในฐานะ Administrator

## 🎮 การใช้งานเมนูจัดการ

หลังติดตั้งเสร็จ พิมพ์คำสั่ง:

```bash
hosting
```

### เมนูที่มีให้ใช้งาน

| หมายเลข | ฟังก์ชัน | รายละเอียด |
|---------|---------|-----------|
| 1 | Exit Script | ออกจากเมนู |
| 2 | Update | ตรวจสอบและอัปเดตเวอร์ชันจาก GitHub Releases |
| 3 | Uninstall | ถอนการติดตั้งพร้อมยืนยัน 2 ครั้ง |
| 4 | Change Domain | เปลี่ยนโดเมน (ตรวจสอบ DNS อัตโนมัติ) |
| 5 | Change Web Server | เปลี่ยน Web Server |
| 6 | Change Database | เปลี่ยน Database |
| 7 | Change SSL Provider | เปลี่ยน SSL Provider |
| 8 | Change Web Port | เปลี่ยน Port |
| 9 | View Current Settings | ดูการตั้งค่าปัจจุบัน |
| 10 | Reset Username & Password | รีเซ็ตรหัสผ่าน |
| 11 | Restart the Website | รีสตาร์ทบริการทั้งหมด |
| 12 | Back up Data | สำรองข้อมูล |

## ⚙️ โครงสร้างไฟล์

```
hosting-panel/
├── REPO                  # ← แก้ที่นี่ จบทุกไฟล์
├── VERSION               # ← แก้ที่นี่ จบทุกไฟล์
├── install.sh            # ตัวติดตั้ง Linux
├── install.ps1           # ตัวติดตั้ง Windows
├── hosting.sh            # เมนูจัดการ Linux
├── hosting.ps1           # เมนูจัดการ Windows
├── build.sh              # สคริปต์ช่วย build (optional)
├── README.md             # คู่มือภาษาไทย
└── src/
    ├── lib/              # ไฟล์ช่วยเหลือ
    └── config/           # Templates ต่างๆ
```

## 🔒 ระบบความปลอดภัย

- **Always HTTPS Redirect**: บังคับใช้ HTTPS อัตโนมัติ
- **HSTS**: HTTP Strict Transport Security
- **TLS 1.2/1.3 Only**: ปิดการใช้งาน TLS รุ่นเก่า
- **X-Frame-Options**: ป้องกัน Clickjacking
- **X-XSS-Protection**: ป้องกัน XSS Attack
- **Content-Security-Policy**: จำกัดแหล่งที่มาของ Content
- **Bot Fight Mode** (Cloudflare): ป้องกัน Bot
- **Hotlink Protection** (Cloudflare): ป้องกันการ Hotlink

## 📝 หมายเหตุ

- สำหรับ **LiteSpeed** ต้องติดตั้ง License เองหลังติดตั้ง (ระบบจะแจ้งเตือน)
- **SQLite** ไม่ต้องใช้ Service แยก (ไฟล์ฐานข้อมูล)
- ระบบจะบล็อก Port ที่สำคัญ เช่น 22, 25, 53, 3306, 5432, 6379, 27017

## 📄 License

MIT License - ใช้งานได้ฟรี

---

**พัฒนาโดย:** Hosting Panel Team
**Repository:** Phechr-2025/Hosting

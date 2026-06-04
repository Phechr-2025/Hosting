#!/bin/bash
# ============================================================
# Build Script - แก้ REPO/VERSION ทีเดียวจบทุกไฟล์
# ============================================================

# อ่านค่าจากไฟล์เดียว
REPO=$(cat REPO 2>/dev/null || echo "Phechr-2025/Hosting")
VERSION=$(cat VERSION 2>/dev/null || echo "v1.0.0")

echo "🔄 Injecting REPO=$REPO and VERSION=$VERSION into all scripts..."

# แก้ไขทุกไฟล์
for file in install.sh install.ps1 hosting.sh hosting.ps1; do
    if [[ -f "$file" ]]; then
        # แทนที่ placeholder ด้วยค่าจริง
        sed -i "s|{{GITHUB_REPO}}|$REPO|g" "$file"
        sed -i "s|{{VERSION}}|$VERSION|g" "$file"
        echo "  ✅ $file"
    fi
done

echo ""
echo "🎉 Done! แก้ทีเดียวจบทุกไฟล์"

#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_PATH="$DIR/MyOpenKey.cer"

if [ ! -f "$CERT_PATH" ]; then
    echo "❌ Không tìm thấy file chứng chỉ: $CERT_PATH"
    exit 1
fi

echo "==> 🔑 Đang cài đặt chứng chỉ MyOpenKey vào Keychain..."
security add-certificate -k ~/Library/Keychains/login.keychain-db "$CERT_PATH" 2>/dev/null || true
security add-trusted-cert -r trustRoot -p codeSign "$CERT_PATH"

echo "==> ✅ Cài đặt và kích hoạt tin cậy chứng chỉ thành công!"
echo "Quyền Trợ năng (Accessibility) của MyOpenKey sẽ được giữ nguyên qua mọi bản tự động cập nhật."

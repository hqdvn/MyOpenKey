# Hướng dẫn biên dịch MyOpenKey cho macOS

Tài liệu này hướng dẫn cách tự biên dịch **MyOpenKey** từ mã nguồn dành cho các nhà phát triển.

---

## 📋 Yêu cầu hệ thống

- **Hệ điều hành:** macOS 12.0 (Monterey) trở lên.
- **Công cụ:** Xcode 14.0 trở lên (hỗ trợ đầy đủ Xcode 15, 16 và mới hơn).
- **Kiến trúc:** Universal Binary (chạy native trên cả chip Apple Silicon M-series và Intel x86_64).

---

## 🚀 Cách 1: Biên dịch nhanh bằng Terminal (Khuyên dùng)

Mở **Terminal** và chạy các lệnh sau:

```bash
# 1. Tải mã nguồn về máy
git clone https://github.com/hqdvn/MyOpenKey.git
cd MyOpenKey

# 2. Biên dịch bản Release (Universal Binary)
xcodebuild -project Sources/OpenKey/macOS/OpenKey.xcodeproj \
  -scheme OpenKey \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build

# 3. Cài đặt vào thư mục Applications
rm -rf /Applications/MyOpenKey.app
cp -R build/Build/Products/Release/MyOpenKey.app /Applications/

# 4. Mở ứng dụng
open /Applications/MyOpenKey.app
```

Sau khi mở, bạn chỉ cần vào **Cài đặt hệ thống (System Settings) ➔ Quyền riêng tư & Bảo mật (Privacy & Security) ➔ Trợ năng (Accessibility)** và kích hoạt quyền cho `MyOpenKey.app`.

---

## 🖥️ Cách 2: Biên dịch qua giao diện Xcode

1. Mở file project tại đường dẫn:
   ```
   Sources/OpenKey/macOS/OpenKey.xcodeproj
   ```
2. Trên thanh công cụ trên cùng của Xcode, chọn Scheme là **OpenKey** và thiết bị đích là **My Mac**.
3. Vào menu **Product ➔ Build** (hoặc nhấn tổ hợp phím `⌘ + B`) để tiến hành biên dịch.
4. Để xuất file `.app` hoàn chỉnh:
   - Vào menu **Product ➔ Archive**.
   - Khi cửa sổ Archives hiện ra, chọn bản build vừa xong và bấm **Distribute App**.
   - Chọn phương thức phân phối nội bộ (Copy App / Custom) và lưu file `MyOpenKey.app` vào thư mục của bạn.

---

## 🔑 Mẹo giữ quyền Accessibility khi tự build cục bộ

Trên macOS, khi một ứng dụng được ký ad-hoc (`CODE_SIGN_IDENTITY=-`), mã băm chứng chỉ (`cdhash`) sẽ thay đổi sau mỗi lần biên dịch, dẫn đến việc macOS tự động thu hồi quyền Trợ năng (Accessibility).

Để giữ quyền cố định qua các lần build, bạn chỉ cần tạo một chứng chỉ ký số cục bộ 1 lần duy nhất:

```bash
# 1. Tạo chứng chỉ ký số cá nhân (chỉ chạy 1 lần)
cat << 'EOF' > /tmp/cert.cnf
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=MyOpenKey Local Signing
[ext]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=critical,CA:false
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/key.pem -out /tmp/cert.pem -days 3650 -config /tmp/cert.cnf 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey /tmp/key.pem -in /tmp/cert.pem -out /tmp/cert.p12 -passout pass:openkey 2>/dev/null
security import /tmp/cert.p12 -P openkey -T /usr/bin/codesign
rm -f /tmp/cert.cnf /tmp/key.pem /tmp/cert.pem /tmp/cert.p12
```

Sau đó khi biên dịch bằng Terminal, truyền tên chứng chỉ vào lệnh build để ứng dụng được tự động ký luôn:

```bash
xcodebuild -project Sources/OpenKey/macOS/OpenKey.xcodeproj \
  -scheme OpenKey -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="MyOpenKey Local Signing" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Hoặc nếu đã build xong, ký đè bằng lệnh:
```bash
codesign --force --deep -s "MyOpenKey Local Signing" /Applications/MyOpenKey.app
```

---

## 👨‍💻 Thông tin tác giả & Giấy phép

- **Tác giả phát triển:** **Huỳnh Quốc Đạt**
  - Website: [hqd.vn](https://hqd.vn)
  - Email: [work@hqd.vn](mailto:work@hqd.vn)
  - Kho mã nguồn: [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey)
- **Ghi nhận nguồn gốc:** Dự án phát triển dựa trên nền tảng bộ máy gõ [OpenKey](https://github.com/tuyenvm/OpenKey) của tác giả Mai Vũ Tuyên (© 2019).
- **Giấy phép:** [GNU General Public License v3.0 (GPLv3)](LICENSE).

#!/bin/bash
set -eo pipefail

# ==============================================================================
#  MyOpenKey Release & Installer Build Script for macOS
#  Author: Huỳnh Quốc Đạt (hqd.vn / work@hqd.vn)
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "==> 🧹 Dọn dẹp thư mục build cũ..."
rm -rf build dist
mkdir -p dist

PROJECT="Sources/OpenKey/macOS/OpenKey.xcodeproj"
SCHEME="OpenKey"
CONFIGURATION="Release"

# Kiểm tra xem có chứng chỉ "MyOpenKey Local Signing" trong Keychain không
SIGN_IDENTITY="-"
if security find-identity -p codesigning | grep -q "MyOpenKey Local Signing"; then
    SIGN_IDENTITY="MyOpenKey Local Signing"
    echo "==> 🔑 Phát hiện chứng chỉ ký số: $SIGN_IDENTITY"
else
    echo "==> ⚠️  Không tìm thấy chứng chỉ 'MyOpenKey Local Signing', dùng chữ ký ad-hoc (-)"
fi

echo "==> 🔨 Đang biên dịch Release (Universal Binary: Apple Silicon & Intel)..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  build

APP_PATH="build/Build/Products/Release/MyOpenKey.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Lỗi: Không tìm thấy $APP_PATH sau khi biên dịch!"
    exit 1
fi

# Lấy phiên bản từ Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.02")
echo "==> 📦 Phiên bản: $VERSION"

DMG_NAME="MyOpenKey-$VERSION.dmg"
ZIP_NAME="MyOpenKey-$VERSION.zip"

# 1. Tạo gói .ZIP (dành cho Homebrew và Direct Download)
echo "==> 🗜️  Đang đóng gói ZIP: dist/$ZIP_NAME..."
ditto -c -k --keepParent "$APP_PATH" "dist/$ZIP_NAME"

# 2. Tạo bộ cài kéo-thả .DMG
echo "==> 💿 Đang tạo bộ cài DMG: dist/$DMG_NAME..."
STAGING_DIR=$(mktemp -d /tmp/myopenkey_dmg.XXXXXX)
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "MyOpenKey" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "dist/$DMG_NAME" >/dev/null

rm -rf "$STAGING_DIR"

# 3. Tạo feed tự động cập nhật Sparkle (appcast.xml)
echo "==> ⚡ Đang tạo feed cập nhật Sparkle: dist/appcast.xml..."
APPCAST_STAGING=$(mktemp -d /tmp/appcast_staging.XXXXXX)
cp "dist/$DMG_NAME" "$APPCAST_STAGING/"

if [ -f "$ROOT_DIR/appcast.xml" ]; then
    cp "$ROOT_DIR/appcast.xml" "$APPCAST_STAGING/appcast.xml"
fi

GEN_ARGS=(--download-url-prefix "https://github.com/hqdvn/MyOpenKey/releases/download/v$VERSION/")
if [ -n "$SPARKLE_PRIVATE_KEY" ]; then
    echo "$SPARKLE_PRIVATE_KEY" | ./Tools/sparkle/generate_appcast --ed-key-file - "${GEN_ARGS[@]}" "$APPCAST_STAGING/" || true
elif [ -f "/tmp/sparkle_private_key.txt" ]; then
    ./Tools/sparkle/generate_appcast --ed-key-file /tmp/sparkle_private_key.txt "${GEN_ARGS[@]}" "$APPCAST_STAGING/" || true
else
    ./Tools/sparkle/generate_appcast "${GEN_ARGS[@]}" "$APPCAST_STAGING/" || true
fi

if [ -f "$APPCAST_STAGING/appcast.xml" ]; then
    cp "$APPCAST_STAGING/appcast.xml" "dist/appcast.xml"
    cp "$APPCAST_STAGING/appcast.xml" "$ROOT_DIR/appcast.xml"
fi
rm -rf "$APPCAST_STAGING"

# 4. Tạo mã băm SHA-256
echo "==> 🔒 Đang tạo mã kiểm tra SHA-256..."
cd dist
shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > SHA256SUMS.txt
cd "$ROOT_DIR"

echo ""
echo "=============================================================================="
echo "🎉 HOÀN TẤT BIÊN DỊCH VÀ ĐÓNG GÓI THÀNH CÔNG!"
echo "=============================================================================="
ls -lh dist/
echo ""
cat dist/SHA256SUMS.txt
echo "=============================================================================="

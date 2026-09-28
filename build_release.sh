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

# Ký Developer ID + notarize (Apple Developer Program, Team L4ADXX588J).
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Quoc Dat Huynh (L4ADXX588J)}"
TEAM_ID="L4ADXX588J"
if ! security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
    echo "❌ Lỗi: Không tìm thấy chứng chỉ '$SIGN_IDENTITY' trong Keychain!"
    exit 1
fi
echo "==> 🔑 Chứng chỉ ký: $SIGN_IDENTITY"

# Xác thực notarytool: CI truyền API key qua biến môi trường,
# máy local dùng profile đã lưu bằng `xcrun notarytool store-credentials MyOpenKey`.
if [ -n "$NOTARY_KEY_P8" ]; then
    NOTARY_KEY_FILE=$(mktemp /tmp/notary_key.XXXXXX)
    trap 'rm -f "$NOTARY_KEY_FILE"' EXIT
    printf '%s\n' "$NOTARY_KEY_P8" > "$NOTARY_KEY_FILE"
    chmod 600 "$NOTARY_KEY_FILE"
    NOTARY_AUTH=(--key "$NOTARY_KEY_FILE" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
else
    NOTARY_AUTH=(--keychain-profile "${NOTARY_PROFILE:-MyOpenKey}")
fi

# notarize <file>: gửi Apple kiểm tra, dừng script nếu bị từ chối
notarize() {
    local result
    result=$(mktemp /tmp/notary_result.XXXXXX)
    xcrun notarytool submit "$1" "${NOTARY_AUTH[@]}" --wait --output-format json > "$result"
    local status id
    status=$(plutil -extract status raw -o - "$result" 2>/dev/null || echo "Unknown")
    id=$(plutil -extract id raw -o - "$result" 2>/dev/null || echo "")
    rm -f "$result"
    echo "    Notarization: $status (ID: $id)"
    if [ "$status" != "Accepted" ]; then
        [ -n "$id" ] && xcrun notarytool log "$id" "${NOTARY_AUTH[@]}"
        exit 1
    fi
}

echo "==> 🔨 Đang biên dịch Release (Universal Binary: Apple Silicon & Intel)..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

APP_PATH="build/Build/Products/Release/MyOpenKey.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Lỗi: Không tìm thấy $APP_PATH sau khi biên dịch!"
    exit 1
fi

# Ký từ trong ra ngoài: ký framework không thay chữ ký của các helper lồng bên trong Sparkle.
# Helper giữ entitlements gốc của Sparkle; app ký lại bằng entitlements của dự án
# (không có get-task-allow, notarization sẽ từ chối nếu có).
echo "==> ✍️  Đang ký Developer ID (hardened runtime + timestamp)..."
SPARKLE="$APP_PATH/Contents/Frameworks/Sparkle.framework"
for component in \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE"; do
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp \
        --preserve-metadata=identifier,entitlements "$component"
done
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp \
    --entitlements "Sources/OpenKey/macOS/ModernKey/ModernKey.entitlements" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
if codesign -d --entitlements - "$APP_PATH" 2>/dev/null | grep -q get-task-allow; then
    echo "❌ Lỗi: app vẫn còn entitlement get-task-allow!"
    exit 1
fi

echo "==> 🍎 Đang notarize ứng dụng..."
NOTARY_ZIP=$(mktemp -d /tmp/myopenkey_notary.XXXXXX)/MyOpenKey.zip
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
notarize "$NOTARY_ZIP"
rm -rf "$(dirname "$NOTARY_ZIP")"
xcrun stapler staple "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

# Lấy phiên bản từ Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.06")
echo "==> 📦 Phiên bản: $VERSION"

DMG_NAME="MyOpenKey-$VERSION.dmg"
ZIP_NAME="MyOpenKey-$VERSION.zip"

# 1. Tạo gói .ZIP (dành cho Homebrew và Direct Download)
echo "==> 🗜️  Đang đóng gói ZIP: dist/$ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "dist/$ZIP_NAME"

# 2. Tạo bộ cài kéo-thả .DMG
echo "==> 💿 Đang tạo bộ cài DMG: dist/$DMG_NAME..."
STAGING_DIR=$(mktemp -d /tmp/myopenkey_dmg.XXXXXX)
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "MyOpenKey" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "dist/$DMG_NAME" >/dev/null

echo "==> 🍎 Đang ký và notarize DMG..."
codesign --force --sign "$SIGN_IDENTITY" --timestamp "dist/$DMG_NAME"
notarize "dist/$DMG_NAME"
xcrun stapler staple "dist/$DMG_NAME"
spctl --assess --type open --context context:primary-signature --verbose=2 "dist/$DMG_NAME"

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

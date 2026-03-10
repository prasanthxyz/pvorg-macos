#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-pvorg}"
PRODUCT_NAME="${PRODUCT_NAME:-pvorg-native}"
BUNDLE_ID="${BUNDLE_ID:-com.pvorg.native}"
VERSION="${VERSION:-1.0.0}"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

# Prefer full Xcode toolchain by default to avoid CLT/SDK mismatch.
if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

SCRATCH_PATH="${SCRATCH_PATH:-$ROOT_DIR/.build/spm-scratch}"
CACHE_PATH="${CACHE_PATH:-$ROOT_DIR/.build/spm-cache}"
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
export CLANG_MODULE_CACHE_PATH

mkdir -p "$SCRATCH_PATH" "$CACHE_PATH" "$DIST_DIR"

swift build \
  --package-path "$ROOT_DIR" \
  -c "$CONFIGURATION" \
  --scratch-path "$SCRATCH_PATH" \
  --cache-path "$CACHE_PATH"

BIN_PATH="$(
  swift build \
    --package-path "$ROOT_DIR" \
    -c "$CONFIGURATION" \
    --show-bin-path \
    --scratch-path "$SCRATCH_PATH" \
    --cache-path "$CACHE_PATH"
)"
BIN_EXEC="$BIN_PATH/$PRODUCT_NAME"

if [[ ! -x "$BIN_EXEC" ]]; then
  echo "Build output missing: $BIN_EXEC" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_EXEC" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "Compiling assets..."
xcrun actool "$ROOT_DIR/Sources/PvorgNative/Resources/Assets.xcassets" \
  --compile "$APP_DIR/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$SCRATCH_PATH/AppIconPartialInfo.plist"

cat >"$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
EOF

# Ad-hoc signing helps avoid some launch warnings for local builds.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --timestamp=none "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "App bundle created:"
echo "  $APP_DIR"
echo ""
echo "Run with:"
echo "  open \"$APP_DIR\""

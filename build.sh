#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/MacRight.app/Contents"
EXT_DIR="$APP_DIR/PlugIns/FinderSyncExtension.appex/Contents"

echo "==> Cleaning..."
rm -rf "$BUILD_DIR"

echo "==> Creating bundle structure..."
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
mkdir -p "$EXT_DIR/MacOS" "$EXT_DIR/Resources/Templates"

HOST_SOURCES=(
  "$PROJECT_DIR/Shared/Constants.swift"
  "$PROJECT_DIR/Shared/Preferences.swift"
  "$PROJECT_DIR/MacRight/MacRightApp.swift"
  "$PROJECT_DIR/MacRight/Views/ContentView.swift"
  "$PROJECT_DIR/MacRight/Views/SettingsView.swift"
)

EXT_SOURCES=(
  "$PROJECT_DIR/Shared/Constants.swift"
  "$PROJECT_DIR/Shared/Preferences.swift"
  "$PROJECT_DIR/FinderSyncExtension/FinderSync.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/FileCreator.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/TerminalLauncher.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/CmuxLauncher.swift"
)

echo "==> Compiling host app (universal binary)..."
for ARCH in arm64 x86_64; do
  swiftc \
    -sdk "$SDK_PATH" \
    -target ${ARCH}-apple-macosx13.0 \
    -F "$SDK_PATH/System/Library/Frameworks" \
    -framework Cocoa -framework FinderSync -framework SwiftUI \
    -module-name MacRight \
    -emit-executable \
    -o "$BUILD_DIR/MacRight_${ARCH}" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    "${HOST_SOURCES[@]}"
done
lipo -create "$BUILD_DIR/MacRight_arm64" "$BUILD_DIR/MacRight_x86_64" -output "$APP_DIR/MacOS/MacRight"
rm "$BUILD_DIR/MacRight_arm64" "$BUILD_DIR/MacRight_x86_64"

echo "==> Compiling Finder Sync Extension (universal binary)..."
for ARCH in arm64 x86_64; do
  swiftc \
    -sdk "$SDK_PATH" \
    -target ${ARCH}-apple-macosx13.0 \
    -F "$SDK_PATH/System/Library/Frameworks" \
    -framework FinderSync -framework Cocoa -framework UniformTypeIdentifiers \
    -module-name FinderSyncExtension \
    -emit-executable \
    -o "$BUILD_DIR/FinderSyncExtension_${ARCH}" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "${EXT_SOURCES[@]}"
done
lipo -create "$BUILD_DIR/FinderSyncExtension_arm64" "$BUILD_DIR/FinderSyncExtension_x86_64" -output "$EXT_DIR/MacOS/FinderSyncExtension"
rm "$BUILD_DIR/FinderSyncExtension_arm64" "$BUILD_DIR/FinderSyncExtension_x86_64"

echo "==> Copying resources..."
cp "$PROJECT_DIR/FinderSyncExtension/Resources/Templates/blank."* "$EXT_DIR/Resources/Templates/"

# Host app Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MacRight</string>
    <key>CFBundleIdentifier</key><string>com.macright.app</string>
    <key>CFBundleName</key><string>MacRight</string>
    <key>CFBundleDisplayName</key><string>MacRight</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Extension Info.plist
cat > "$EXT_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>FinderSyncExtension</string>
    <key>CFBundleIdentifier</key><string>com.macright.app.FinderSyncExtension</string>
    <key>CFBundleName</key><string>FinderSyncExtension</string>
    <key>CFBundleDisplayName</key><string>MacRight Finder Extension</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>XPC!</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key><dict/>
        <key>NSExtensionPointIdentifier</key><string>com.apple.FinderSync</string>
        <key>NSExtensionPrincipalClass</key><string>FinderSyncExtension.FinderSync</string>
    </dict>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$APP_DIR/PkgInfo"

# 如果传入了版本号参数，写入 Info.plist
VERSION="${1:-}"
if [ -n "$VERSION" ]; then
  # 去掉 v 前缀
  VER="${VERSION#v}"
  echo "==> Setting version to $VER..."
  sed -i '' "s|<string>1.0.0</string>|<string>$VER</string>|g" "$APP_DIR/Info.plist"
  sed -i '' "s|<string>1.0.0</string>|<string>$VER</string>|g" "$EXT_DIR/Info.plist"
fi

echo "==> Signing..."
codesign --force --sign - --entitlements "$PROJECT_DIR/FinderSyncExtension/FinderSyncExtension.entitlements" "$BUILD_DIR/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex"
codesign --force --sign - --entitlements "$PROJECT_DIR/MacRight/MacRight.entitlements" "$BUILD_DIR/MacRight.app"

# CI 模式：仅构建签名，不安装到本地
if [ "${CI:-}" = "true" ]; then
  echo "==> Done! (CI mode, skip local install)"
  exit 0
fi

echo "==> Installing to /Applications..."
killall MacRight 2>/dev/null || true
rm -rf /Applications/MacRight.app
cp -R "$BUILD_DIR/MacRight.app" /Applications/MacRight.app
codesign --force --sign - --entitlements "$PROJECT_DIR/FinderSyncExtension/FinderSyncExtension.entitlements" /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex
codesign --force --sign - --entitlements "$PROJECT_DIR/MacRight/MacRight.entitlements" /Applications/MacRight.app

echo "==> Cleaning build dir extension to avoid duplicate registration..."
rm -rf "$BUILD_DIR/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUILD_DIR/MacRight.app" 2>/dev/null || true

echo "==> Registering extension..."
killall pkd 2>/dev/null || true
sleep 1
pluginkit -e use -i com.macright.app.FinderSyncExtension 2>/dev/null || true

echo "==> Done! Launching..."
open /Applications/MacRight.app
sleep 2
pluginkit -m -p com.apple.FinderSync 2>/dev/null

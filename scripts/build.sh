#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Default App.app"
bin="$app/Contents/MacOS/DefaultApp"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

swift build -c release --package-path "$root" >/dev/null
cp "$root/.build/release/DefaultApp" "$bin"

# --- Info.plist ---
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>默认应用</string>
    <key>CFBundleDisplayName</key>
    <string>默认应用</string>
    <key>CFBundleIdentifier</key>
    <string>local.henry.DefaultApp</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>DefaultApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# --- 图标：SVG -> iconset -> icns ---
iconset="$root/build/AppIcon.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"

for spec in \
  "16 1x" "32 2x" "32 1x" "64 2x" "128 1x" "256 2x" "256 1x" "512 2x" "512 1x" "1024 2x"
do
  size="${spec%% *}"
  scale="${spec##* }"
  case "$scale" in
    1x) name="icon_${size}x${size}.png" ;;
    2x) name="icon_${size}x${size}@2x.png" ;;
  esac
  rsvg-convert -w "$size" -h "$size" "$root/Resources/AppIcon.svg" -o "$iconset/$name"
done

iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp "$root/Resources/AppIcon.svg" "$app/Contents/Resources/AppIcon.svg"

codesign --force --sign - "$app"
codesign --verify --strict "$app"

echo "Built: $app"

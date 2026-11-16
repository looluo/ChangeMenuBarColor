#!/bin/bash

# Build script for ChangeMenuBarColor binary release
# Creates a universal binary that works on both Intel and ARM Macs

set -e

# Set up variables
PROJECT_NAME="ChangeMenuBarColor"
OUTPUT_DIR="./build"
RELEASE_DIR="$OUTPUT_DIR/release"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")

# Create directory structure
echo "Creating build directories..."
mkdir -p "$OUTPUT_DIR/arm64"
mkdir -p "$OUTPUT_DIR/x86_64"
mkdir -p "$RELEASE_DIR"

# The binary output path (same directory for every --arch with the SwiftPM build layout,
# so the binary must be copied out right after each per-arch build)
BIN_PATH=$(swift build --configuration release --arch arm64 --show-bin-path)

# Build for ARM64 architecture (Apple Silicon)
echo "Building for ARM64 architecture (Apple Silicon)..."
swift build --configuration release --arch arm64
cp -f "$BIN_PATH/$PROJECT_NAME" "$OUTPUT_DIR/arm64/"

# Build for x86_64 architecture (Intel)
echo "Building for x86_64 architecture (Intel)..."
swift build --configuration release --arch x86_64
cp -f "$BIN_PATH/$PROJECT_NAME" "$OUTPUT_DIR/x86_64/"

# Create universal binary
echo "Creating universal binary..."
lipo -create -output "$RELEASE_DIR/$PROJECT_NAME" "$OUTPUT_DIR/arm64/$PROJECT_NAME" "$OUTPUT_DIR/x86_64/$PROJECT_NAME"

# Check the binary architectures
echo "Verifying architectures in the universal binary:"
lipo -info "$RELEASE_DIR/$PROJECT_NAME"

echo "Assembling $PROJECT_NAME.app..."
APP="$OUTPUT_DIR/$PROJECT_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$RELEASE_DIR/$PROJECT_NAME" "$APP/Contents/MacOS/$PROJECT_NAME"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.igorkulman.ChangeMenuBarColor.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# App icon: regenerate the icns from the committed source png
mkdir -p "$APP/Contents/Resources"
ICONSET="$OUTPUT_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z $double $double Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp -f Assets/AppIcon.png "$APP/Contents/Resources/AppIcon.png"

# SMAppService requires a code signed bundle; the signature must cover Info.plist
codesign --force --sign - "$APP"

# Create a zip file for distribution
echo "Creating zip archive for distribution..."
cp -f "$RELEASE_DIR/$PROJECT_NAME" "$OUTPUT_DIR/$PROJECT_NAME"
cd "$OUTPUT_DIR" || exit
rm -f "$PROJECT_NAME-$VERSION.zip"
zip -r "$PROJECT_NAME-$VERSION.zip" "$PROJECT_NAME.app" "$PROJECT_NAME" > /dev/null
cd - || exit

echo "✅ Build complete!"
echo "Universal binary is available at: $RELEASE_DIR/$PROJECT_NAME"
echo "Menu bar app is available at: $APP"
echo "Zip archive is available at: $OUTPUT_DIR/$PROJECT_NAME-$VERSION.zip"
#!/bin/zsh
set -eu

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"
if [[ "${1:-}" == "--binary-dir" ]]; then
    BIN_DIR="$2"
else
    swift build -c release --product PDFStudio
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi
APP_DIR="$ROOT_DIR/dist/Folio.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/PDFStudio" "$APP_DIR/Contents/MacOS/Folio.new"
mv -f "$APP_DIR/Contents/MacOS/Folio.new" "$APP_DIR/Contents/MacOS/Folio"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>Folio</string>
    <key>CFBundleDisplayName</key><string>Folio</string>
    <key>CFBundleIdentifier</key><string>com.folio.pdfstudio</string>
    <key>CFBundleExecutable</key><string>Folio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Folio</string>
</dict></plist>
PLIST
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --keepParent --norsrc --noextattr "$APP_DIR" "$ROOT_DIR/dist/Folio.zip"
print "App creada: $APP_DIR"
print "Paquete para copiar o descomprimir fuera de iCloud: $ROOT_DIR/dist/Folio.zip"

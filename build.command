#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p LGBar.app/Contents/MacOS LGBar.app/Contents/Resources .build-cache
xcrun swiftc -swift-version 5 -O -module-cache-path .build-cache -target arm64-apple-macos13.0 Sources/*.swift -o LGBar.app/Contents/MacOS/LGBar -framework AppKit -framework ServiceManagement -framework CoreLocation
cat > LGBar.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.LGBar</string>
<key>CFBundleName</key><string>LGBar</string>
<key>CFBundleExecutable</key><string>LGBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.3.7</string>
<key>CFBundleVersion</key><string>153</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSLocationUsageDescription</key><string>Show the outdoor temperature at your current location. Coordinates are sent to Open-Meteo to retrieve weather.</string>
<key>NSLocationWhenInUseUsageDescription</key><string>Show the outdoor temperature at your current location. Coordinates are sent to Open-Meteo to retrieve weather.</string>
</dict></plist>
PLIST
if [[ "${LG_BAR_RELEASE:-0}" == "1" ]]; then
  rm -f LGBar.app/Contents/Resources/token.txt
elif [[ ! -s token.txt ]]; then
  printf 'token.txt is missing or empty\n' >&2
  exit 1
else
  cp token.txt LGBar.app/Contents/Resources/token.txt
  chmod 600 LGBar.app/Contents/Resources/token.txt
fi
codesign --force --sign - LGBar.app
printf 'Built LGBar.app\n'

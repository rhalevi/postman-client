# PostmanClient

A minimal macOS Postman client built with SwiftUI and Swift Package Manager.

## Features

- HTTP method picker (GET, POST, PUT, DELETE)
- URL bar with monospaced font
- Custom header editor with add/remove
- JSON body editor (POST requests)
- Raw and JSON response viewer
- Collapsible JSON response tree view
- Status code badge with color coding

## Requirements

- macOS 13+
- Swift 5.9+

## Building

```bash
swift build
```

## Running the App

The project is a Swift Package Manager project (no Xcode). To build and run:

```bash
# 1. Build
swift build

# 2. Create an app bundle (required for the app to launch correctly)
mkdir -p PostmanClient.app/Contents/MacOS
cp .build/debug/PostmanClient PostmanClient.app/Contents/MacOS/

# 3. Add Info.plist (required for macOS to recognize it as an app)
cat > PostmanClient.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PostmanClient</string>
    <key>CFBundleIdentifier</key>
    <string>com.postman.client</string>
    <key>CFBundleName</key>
    <string>PostmanClient</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 4. Launch
open PostmanClient.app
```

Alternatively, run `./run.sh` for a quick one-command build + launch (if the script exists).

## Architecture

The project is a Swift Package (not an Xcode project). The main components are:

- `PostmanClientApp.swift` - App entry point
- `ContentView.swift` - UI (form, response area, JSON tree)
- `ContentViewViewModel.swift` - State management, networking, JSON parsing

## License

Private

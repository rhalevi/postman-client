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

## Getting Started

```bash
swift build
```

To run the app, create an app bundle and launch it with `open`:

```bash
mkdir -p PostmanClient.app/Contents/MacOS
cp .build/debug/PostmanClient PostmanClient.app/Contents/MacOS/
open PostmanClient.app
```

Or use the included `Info.plist` in `PostmanClient.app/Contents/` if you've already created the bundle structure.

## Architecture

The project is a Swift Package (not an Xcode project). The main components are:

- `PostmanClientApp.swift` - App entry point
- `ContentView.swift` - UI (form, response area, JSON tree)
- `ContentViewViewModel.swift` - State management, networking, JSON parsing

## License

Private

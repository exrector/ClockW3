# ClockW3 - 24-Hour World Clock

Modern SwiftUI world clock application with iOS home screen widget support.

## Features

- **24-hour clock face** with digits 01-24
- **Multiple time zones** with IATA city codes
- **Interactive rotation** via drag gestures
- **iOS widget** for home screen
- **Smart orbit distribution** - city labels distributed intelligently to avoid overlaps
- **App Group sync** - settings shared between app and widget
- **Light/Dark mode** support

## Project Structure

```
ClockW3/
├── Shared/              # Code shared between app and widget
│   ├── Models/          # Data models (WorldCity, ClockConstants)
│   ├── ViewModels/      # View models (ClockViewModel)
│   ├── Views/           # SwiftUI views (ClockFaceView, CityArrowsView, etc.)
│   └── Helpers/         # Utilities (AngleCalculations, SharedUserDefaults, etc.)
├── ClockW3/             # App-specific code
│   ├── ContentView.swift
│   ├── SwiftUIClockApp.swift
│   └── Helpers/         # App-specific helpers (ClockHaptics)
└── ClockW3Widget/       # Widget-specific code
    └── ClockW3Widget.swift
```

## Architecture

The project uses **PBXFileSystemSynchronized** (Xcode 16+) for automatic file synchronization.

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation on:
- Coordinate system and angle calculations
- Radius definitions and sizing
- Project structure and file organization
- How to add new files

## Setup

### Prerequisites
- Xcode 16.1 or later
- iOS 18.6+ deployment target

### App Groups Configuration
For app-widget synchronization, configure App Groups in both targets:

1. **ClockW3 target:**
   - Signing & Capabilities → Add Capability → App Groups
   - Enable: `group.exrector.ClockW3`

2. **ClockW3WidgetExtension target:**
   - Signing & Capabilities → Add Capability → App Groups
   - Enable: `group.exrector.ClockW3`

## Usage

### Adding Cities
Tap the settings icon to select cities from the time zone picker. Selected cities are automatically synchronized between the app and widget.

### Interactive Rotation
- **Drag** to rotate the clock face
- **Release** to auto-snap to nearest tick mark
- Clock remembers rotation state

### Widget
Add the ClockW3 widget to your home screen to see the clock without opening the app.

## Technical Details

### Key Components

**Shared Code:**
- `ClockFaceView` - Main clock face component
- `CityArrowsView` - City arrows with time-based positioning
- `StaticBackgroundView` - Clock ticks and hour numbers
- `CityOrbitDistribution` - Smart algorithm for distributing city labels across two orbits
- `SharedUserDefaults` - Shared storage between app and widget

**Angle Calculation:**
```swift
// 18:00 = 0° reference point
let hour24 = Double(hour) + Double(minute) / 60.0
let degrees = hour24 * 15.0 - 18.0 * 15.0
let angle = -degrees * Double.pi / 180.0
```

### Performance
- Canvas for complex drawing (ticks, color segments)
- ForEach for repeating elements
- Smart orbit distribution reduces frame-by-frame calculations

## Recent Updates

### 2025-10-12
- **Refactored project structure**: Created dedicated `Shared/` directory for app-widget code
- **Removed dead code**: Deleted ~700 lines of unused alternate rendering stack
- **Fixed widget sync**: Settings now write to shared UserDefaults
- **Improved widget**: Uses color palette instead of hardcoded colors
- **Added documentation**: Comprehensive ARCHITECTURE.md with project structure guide

### 2025-10-09
- Simplified UI (removed info panel, reset button)
- Added IATA city codes instead of full names
- Implemented smart city orbit distribution algorithm
- Created iOS widget with minute-level updates

## License

Ported from original TimeVector2 project.

# Recovery Notes - Project Structure History

## 2025-10-12: Major Refactoring

### What Changed
- **Created `Shared/` directory** for code shared between app and widget
- **Removed dead code** (~700 lines of unused alternate rendering stack)
- **Fixed app-widget synchronization** using App Groups
- **Improved project structure** with PBXFileSystemSynchronized

### Current Project Structure

```
ClockW3/
├── Shared/              # Code shared between app and widget
│   ├── Models/          # WorldCity, ClockConstants
│   ├── ViewModels/      # ClockViewModel
│   ├── Views/           # ClockFaceView, CityArrowsView, StaticBackgroundView
│   └── Helpers/         # AngleCalculations, SharedUserDefaults, CityOrbitDistribution
├── ClockW3/             # App-specific code
│   ├── ContentView.swift
│   ├── SwiftUIClockApp.swift
│   ├── Helpers/ClockHaptics.swift
│   └── Assets.xcassets/
├── ClockW3Widget/       # Widget Extension
│   ├── ClockW3Widget.swift
│   ├── Info.plist
│   └── Assets.xcassets/
├── ClockW3.xcodeproj/
└── ARCHITECTURE.md      # Detailed project documentation
```

### Key Improvements
- ✅ No manual `membershipExceptions` needed
- ✅ Files automatically included in correct targets
- ✅ Widget syncs with app via `group.exrector.ClockW3` App Group
- ✅ Cleaner git history (no project.pbxproj conflicts)

## Previous Issues (2025-10-09)

### Original Problem
Grok modified `ClockW3.xcodeproj/project.pbxproj` causing:
```
The project cannot be opened because it is in an unsupported Xcode project file format.
```

### How It Was Fixed
```bash
git restore ClockW3.xcodeproj/project.pbxproj
git restore ClockW3.xcodeproj/xcuserdata/exrector.xcuserdatad/xcschemes/xcschememanagement.plist
git reset HEAD Widget/
rm -rf Widget/ ClockWidgetExtension/ WIDGET_SETUP.md
```

## How to Work with This Project

### Adding New Files

**For shared code (used by both app and widget):**
- Create file in `Shared/` directory
- File automatically available to both targets

**For app-only code:**
- Create file in `ClockW3/`
- Available only to main app

**For widget-only code:**
- Create file in `ClockW3Widget/`
- Available only to widget

### Building the Project

```bash
# For iOS Simulator
xcodebuild -scheme ClockW3 -destination 'platform=iOS Simulator,name=iPhone 16' build

# For macOS
xcodebuild -scheme ClockW3 -destination 'platform=macOS' build
```

### App Groups Setup

Both targets need App Groups capability:

1. **ClockW3 target:**
   - Signing & Capabilities → + Capability → App Groups
   - Enable: `group.exrector.ClockW3`

2. **ClockW3WidgetExtension target:**
   - Signing & Capabilities → + Capability → App Groups
   - Enable: `group.exrector.ClockW3`

## Best Practices

### ✅ DO
- Use Xcode UI for target/file management
- Keep shared code in `Shared/` directory
- Read `ARCHITECTURE.md` before making structural changes
- Let PBXFileSystemSynchronized handle file membership automatically

### ❌ DON'T
- Manually edit `project.pbxproj` unless absolutely necessary
- Put shared code in `ClockW3/` directory
- Create directories named "Shared" inside app-specific folders (causes ambiguity)
- Mix app-specific and shared code

## Current Status

### ✅ Working
- Project opens in Xcode 16.1+
- Builds successfully for iOS and macOS
- Widget Extension functional
- App and widget share city selections
- No dead code or duplicate logic

### 📚 Documentation
- `README.md` - Project overview and usage
- `ARCHITECTURE.md` - Technical details, coordinate system, project structure
- `.gitignore` - Excludes .DS_Store and Xcode artifacts

## Migration Guide

If you have old code referencing removed files:

**Dead files removed:**
- `ClockW3/Shared/ClockCanvasView.swift`
- `ClockW3/Shared/ClockController.swift`
- `ClockW3/Shared/ClockDrawingHelpers.swift`
- `ClockW3/Shared/ClockModel.swift`
- `ClockW3/Shared/ClockPhysics.swift`
- `ClockW3/Views/ClockViewRepresentable.swift`
- `ClockW3/Views/CoreGraphicsClockView.swift`

**Current rendering:**
Use `Shared/Views/ClockFaceView.swift` and `Shared/Views/CityArrowsView.swift`

## Troubleshooting

**Widget not updating with city changes:**
- Verify App Groups are configured in both targets
- Check `SharedUserDefaults.appGroupID` matches "group.exrector.ClockW3"

**Files not building:**
- Ensure files are in correct directory (`Shared/` vs `ClockW3/`)
- Let Xcode rescan: Product → Clean Build Folder

**Git conflicts in project.pbxproj:**
- Prefer Xcode UI changes over manual edits
- PBXFileSystemSynchronized minimizes these conflicts

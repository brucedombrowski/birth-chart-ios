# Birth Chart iOS — CLAUDE.md

## Project Overview
iOS birth chart calculator with 3D solar system and Earth orbit visualization. Pure Swift, no external dependencies. Uses SceneKit for 3D rendering and GameController framework for DualSense (PS5 controller) support.

## Build & Deploy

```bash
# Build for device
xcodebuild -project /Users/brucedombrowski/birth-chart-ios/BirthChart.xcodeproj \
  -scheme BirthChart \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/bc-build \
  -allowProvisioningUpdates build

# Install on iPhone
xcrun devicectl device install app \
  --device 00008140-001C71EA0E80401C \
  /tmp/bc-build/Build/Products/Debug-iphoneos/BirthChart.app
```

**Note:** SourceKit often reports false positives (e.g., "Cannot find 'UIColor'", "Cannot find 'GeocentricScene'") because it doesn't have full project context. If the `xcodebuild` command succeeds, these errors can be ignored.

## Architecture

```
BirthChart/
├── App/BirthChartApp.swift              # App entry point with NavigationStack
├── Computation/
│   ├── EphemerisEngine.swift            # JPL Keplerian ephemeris, Kepler solver
│   ├── CoordinateTransform.swift        # Julian date, GMST, ecliptic/equatorial
│   ├── AscendantCalculator.swift        # ASC/MC from local sidereal time
│   ├── AspectDetector.swift             # Aspect detection (conjunction through opposition)
│   └── MoonPhase.swift                  # Lunar illumination and phase classification
├── Models/
│   ├── BirthChart.swift                 # BirthData, BirthChartResult
│   ├── CelestialBody.swift             # Planet positions with sign/retrograde
│   ├── ZodiacSign.swift                # 12 signs with symbols, elements, modalities
│   ├── Aspect.swift                    # Aspect types with orbs
│   ├── OrbitalObject.swift             # Satellite orbital mechanics, J2 perturbation
│   ├── ConstellationData.swift         # Star/Constellation models, Precession calculations
│   └── SpaceLaunch.swift               # Launch history model
├── SceneKit/
│   ├── SolarSystemScene.swift          # Heliocentric 3D solar system
│   ├── GeocentricScene.swift           # Earth-centered satellite view
│   └── StarFieldBuilder.swift          # Celestial sphere with stars & constellations
├── Views/
│   ├── ContentView.swift               # Main tab/navigation
│   ├── ChartInputView.swift            # Birth data entry form
│   ├── ChartResultView.swift           # Chart results with ISS birth chart section
│   ├── SolarSystemView.swift           # Heliocentric 3D view + controller
│   ├── EarthOrbitView.swift            # Geocentric 3D view + controller
│   └── LaunchHistoryView.swift         # Space launch timeline
├── Resources/
│   ├── satellites.json                 # 103 satellites with orbital elements & launch years
│   ├── launches.json                   # Historical space launches
│   ├── stars.json                      # 97 stars (RA/Dec/magnitude, J2000)
│   ├── constellation_lines.json        # 22 constellation stick-figure patterns
│   └── earth_texture.jpg              # NASA Blue Marble
└── GameControllerManager.swift         # DualSense controller input handling
```

## Key Technical Details

### DualSense Controller (GameControllerManager.swift)
- Uses `nonisolated(unsafe)` properties for render thread access (SceneKit renderer callback runs off main actor)
- Button edge detection: `crossJustPressed`, `triangleJustPressed`, `squareJustPressed`, `circleJustPressed`
- Analog triggers: `leftTrigger`, `rightTrigger` (0.0-1.0 pressure)
- Stick axes: `leftStickX/Y`, `rightStickX/Y`
- Button mapping: Cross=reset time, Triangle=labels, Square=ISS camera, Circle=pause/play

### Time System
- `timeOffsetDays: Double` tracks offset from initial date
- Pressure-based speed tiers: <25% trigger = 1 day/sec, up to 1 century/sec at full squeeze
- R2 = forward, L2 = backward
- Real-time advancement when triggers released (dt/86400 days per frame)
- Circle button pauses/resumes

### Satellite Mechanics (OrbitalObject.swift)
- Simplified Keplerian orbits (circular approximation)
- J2 perturbation for RAAN precession
- `launchYear` field enables historical filtering
- `SatelliteDatabase.active(at:)` returns satellites launched before given date

### Precession (ConstellationData.swift)
- ~25,772-year cycle, 0.01396°/year
- Applied as Y-axis rotation to celestial sphere
- `Precession.angle(at:)` returns radians from J2000
- `Precession.astrologicalAge(at:)` returns current age name

### Scene Scaling (GeocentricScene.swift)
- Earth radius: 2.0 scene units
- LEO shell: 2.8, MEO: 5.5, GEO: 8.5
- Moon: 12.0, Celestial sphere: 80.0
- Piecewise linear mapping from real altitude to scene radius

### Adding to Xcode Project
When adding new Swift files or resources, you must update `BirthChart.xcodeproj/project.pbxproj`:
1. Generate unique 24-char hex UUIDs for each reference
2. Add PBXFileReference entry
3. Add PBXBuildFile entry (compile sources for .swift, resources for .json/.jpg)
4. Add to PBXGroup children array
5. Add to appropriate PBXSourcesBuildPhase or PBXResourcesBuildPhase

## Design Philosophy
The app uses astrology and birthday personalization as an accessible gateway to teach users real science — orbital mechanics, precession, satellite tracking, celestial coordinates. The experience should be personal (tied to the user's birthday) and discoverable (scrubbing through time reveals real phenomena).

## Common Patterns
- SceneKit views use UIViewRepresentable with a Coordinator that implements SCNSceneRendererDelegate
- Controller input is read in `renderer(_:updateAtTime:)` callback
- Main thread updates via `DispatchQueue.main.async` from render thread
- Heavy computation (chart recomputation) dispatched to `.userInteractive` QoS queue
- JSON data files loaded lazily with static caches in enum namespaces

## Git
- Remote: https://github.com/brucedombrowski/birth-chart-ios.git
- Branch: main
- Commit style: descriptive messages with feature summary

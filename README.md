# BirthChart

iOS birth chart calculator with 3D solar system visualization. Pure Swift — no external dependencies.

## Features

- Full natal chart computation (10 planets + Ascendant, Midheaven, North Node, Lilith)
- Aspect detection (conjunction, sextile, square, trine, opposition)
- Moon phase with illumination percentage
- Element and modality distribution
- Interactive 3D solar system view (SceneKit)
- Offline — all computation runs on device

## Install on Device

1. Open `BirthChart.xcodeproj` in Xcode
2. Select your team under **Signing & Capabilities**
3. Connect your iPhone via USB
4. Select your iPhone as the build target
5. **Cmd+R** to build and run
6. On your iPhone: **Settings > General > VPN & Device Management** > tap your developer profile > **Trust**

## Tech

- SwiftUI + SceneKit
- JPL Keplerian orbital elements
- Kepler's equation (Newton-Raphson)
- Specialized lunar theory (~0.5° accuracy)
- Valid for 1800–2050 CE
- iOS 17.0+

# BirthChart

iOS birth chart calculator with 3D solar system visualization, time travel, and DualSense controller support. Pure Swift — no external dependencies.

## Core Features

- Full natal chart computation (10 planets + Ascendant, Midheaven, North Node, Lilith)
- Aspect detection (conjunction, sextile, square, trine, opposition)
- Moon phase with illumination percentage
- Element and modality distribution
- Offline — all computation runs on device, pure Swift, no external dependencies

## 3D Views (SceneKit)

- **Heliocentric Solar System View** — 3D solar system with all planets at real orbital positions
- **Geocentric Earth Orbit View** — Earth at center with 103 satellites (LEO/MEO/GEO)
- **ISS Cupola Camera** — First-person view from the International Space Station looking down at Earth
- **Constellation Star Field** — 97 real stars with 22 constellation stick-figure patterns on a celestial sphere
- **Precession of the Equinoxes** — Stars shift position over ~25,772-year axial precession cycle; astrological age display (Age of Pisces, Aquarius, etc.)

## DualSense Controller Support (PlayStation 5 controller)

- **Left stick**: orbit camera / pan ISS cupola view
- **Right stick**: zoom
- **L2/R2 triggers**: pressure-based time throttle (analog pressure maps to speed: 1 day/sec → 1 century/sec)
- **Cross (X)**: reset time to present
- **Triangle**: toggle labels
- **Square**: toggle ISS cupola camera
- **Circle**: pause/play real-time advancement

## Time Travel Features

- Scrub forward/backward through time with trigger pressure controlling speed
- Historical satellite filtering — satellites appear/disappear based on launch year (rewind to pre-1957 for empty sky)
- Ancient monument night sky — scrub to Gobekli Tepe (~9500 BCE) or Egyptian pyramids (~2560 BCE) era and see precessed constellation positions
- Astrological age display when time-traveling beyond 1 year
- Real-time satellite orbit advancement when triggers released

## Personal Features

- ISS Birth Chart — shows where the ISS was over Earth when you were born
- Birth chart with zodiac signs, houses, aspects
- Space launch timeline tied to birth year

## Technical Details

- SwiftUI + SceneKit
- JPL Keplerian orbital elements for planetary positions
- Kepler's equation solver (Newton-Raphson)
- Specialized lunar theory (~0.5° accuracy)
- J2 perturbation for satellite RAAN precession
- GameController framework for DualSense support
- Valid for 1800–2050 CE (planetary ephemeris); constellation precession works across full 25,772-year cycle
- iOS 17.0+

## Project Structure

```
BirthChart/
├── App/                    # App entry point
├── Computation/            # Ephemeris engine, coordinate transforms, aspects
├── Models/                 # Data models (zodiac, celestial bodies, satellites, stars)
├── Resources/              # JSON databases, textures, assets
├── SceneKit/               # 3D scene builders (solar system, geocentric, star field)
└── Views/                  # SwiftUI views
```

## Data Files

- **satellites.json** — 103 satellites with orbital elements and launch years
- **launches.json** — Historical space launch database
- **stars.json** — 97 brightest stars with RA/Dec/magnitude (J2000 epoch)
- **constellation_lines.json** — 22 constellation stick-figure patterns
- **earth_texture.jpg** — NASA Blue Marble texture

## Install on Device

1. Open `BirthChart.xcodeproj` in Xcode
2. Select your team under **Signing & Capabilities**
3. Connect your iPhone via USB
4. Select your iPhone as the build target
5. **Cmd+R** to build and run
6. On your iPhone: **Settings > General > VPN & Device Management** > tap your developer profile > **Trust**

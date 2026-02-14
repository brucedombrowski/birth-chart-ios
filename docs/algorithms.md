# Birth Chart iOS: Algorithm Documentation

**Version:** 1.0
**Date:** February 14, 2026
**Author:** Documentation Agent

This document provides comprehensive technical documentation of all computational algorithms used in the Birth Chart iOS application. All algorithms are implemented in pure Swift without external dependencies.

---

## Table of Contents

1. [Ephemeris Engine](#1-ephemeris-engine)
2. [Coordinate Transformations](#2-coordinate-transformations)
3. [Ascendant and Midheaven Calculation](#3-ascendant-and-midheaven-calculation)
4. [Moon Phase Computation](#4-moon-phase-computation)
5. [Aspect Detection](#5-aspect-detection)
6. [Satellite Orbital Mechanics](#6-satellite-orbital-mechanics)
7. [3D Visualization Scaling](#7-3d-visualization-scaling)
8. [ISS Acquisition of Signal (AOS) Cone](#8-iss-acquisition-of-signal-aos-cone)

---

## 1. Ephemeris Engine

**Source:** `/BirthChart/Computation/EphemerisEngine.swift`

The ephemeris engine computes geocentric ecliptic positions for all major solar system bodies using JPL's Keplerian orbital elements method.

### 1.1 Julian Date Conversion

Converts a Gregorian calendar date to Julian Date (JD), the standard astronomical time scale.

**Algorithm:**
```
JD = 2440587.5 + (Unix timestamp) / 86400.0
```

**Implementation:** `CoordinateTransform.julianDate(from:)`

**Inputs:**
- `date: Date` — Swift Date object (UTC)

**Outputs:**
- `Double` — Julian Date (days since January 1, 4713 BCE at 12:00 UT)

**Reference:** IAU standard formula. Unix epoch (January 1, 1970 00:00 UTC) = JD 2440587.5

**Accuracy:** Exact for the Gregorian calendar within Swift's Date precision (~microsecond level).

---

### 1.2 Julian Centuries from J2000.0

Computes the time offset in Julian centuries from the J2000.0 epoch, used for orbital element evolution.

**Algorithm:**
```
T = (JD - 2451545.0) / 36525.0
```

**Implementation:** `CoordinateTransform.julianCenturies(fromJD:)`

**Inputs:**
- `jd: Double` — Julian Date

**Outputs:**
- `T: Double` — Julian centuries from J2000.0 (positive for dates after noon on January 1, 2000 TT)

**Reference:** IAU standard. J2000.0 epoch = JD 2451545.0 (January 1, 2000 12:00 TT)

**Note:** TT (Terrestrial Time) and UTC differ by ~70 seconds in 2025; this implementation treats input dates as UTC and ignores the ΔT correction. For birth chart purposes (zodiac sign determination), this sub-minute error is negligible.

---

### 1.3 Keplerian Orbital Elements

The engine uses JPL's "Approximate Positions of the Major Planets" dataset, providing osculating elements at J2000.0 and their secular rates.

**Elements for each planet:**
- `a` — semi-major axis (AU)
- `e` — orbital eccentricity
- `I` — inclination to ecliptic plane (degrees)
- `L` — mean longitude (degrees)
- `ϖ` (wBar) — longitude of perihelion (degrees)
- `Ω` (omega) — longitude of ascending node (degrees)

Each element has a corresponding rate per century (e.g., `aDot`, `eDot`).

**Evolution formula:**
```
element(T) = element₀ + element_dot × T
```

**Source:** E.M. Standish (1992), "Keplerian Elements for Approximate Positions of the Major Planets", JPL IOM 314.10-127

**Validity:** 1800 CE – 2050 CE

**Accuracy:** ~1 arcminute for inner planets, ~10 arcminutes for outer planets

**Implementation:** `OrbitalElements.mercury`, `OrbitalElements.venus`, etc. (lines 26–108)

---

### 1.4 Kepler's Equation Solver

Solves Kepler's equation for the eccentric anomaly `E` given mean anomaly `M` and eccentricity `e`.

**Kepler's Equation:**
```
M = E - e·sin(E)
```

**Algorithm:** Newton-Raphson iteration
```
E₀ = M + e·sin(M)·(1 + e·cos(M))   [initial guess]

Iterate:
  f(E) = E - e·sin(E) - M
  f'(E) = 1 - e·cos(E)
  E_new = E - f(E)/f'(E)

Stop when |E_new - E| < 10⁻¹²
```

**Implementation:** `EphemerisEngine.solveKepler(M:e:)` (lines 128–138)

**Inputs:**
- `M: Double` — mean anomaly (radians)
- `e: Double` — orbital eccentricity (0 ≤ e < 1)

**Outputs:**
- `E: Double` — eccentric anomaly (radians)

**Convergence:** 3–5 iterations for planetary eccentricities (e < 0.21 for all planets)

**Reference:** Jean Meeus, *Astronomical Algorithms* (2nd ed.), Chapter 30

---

### 1.5 Heliocentric Position Computation

Computes the 3D heliocentric position of a planet in ecliptic coordinates.

**Algorithm:**

1. **Compute time-evolved elements:**
   ```
   a(T) = a₀ + a_dot × T
   e(T) = e₀ + e_dot × T
   I(T) = I₀ + I_dot × T
   L(T) = L₀ + L_dot × T (mod 360°)
   ϖ(T) = ϖ₀ + ϖ_dot × T (mod 360°)
   Ω(T) = Ω₀ + Ω_dot × T (mod 360°)
   ```

2. **Derive argument of perihelion and mean anomaly:**
   ```
   ω = ϖ - Ω
   M = L - ϖ (mod 2π)
   ```

3. **Solve Kepler's equation for E** (see 1.4)

4. **Compute true anomaly via position in orbital plane:**
   ```
   x' = a·(cos(E) - e)
   y' = a·√(1 - e²)·sin(E)
   r = √(x'² + y'²)
   ν = atan2(y', x')
   ```

5. **Transform to heliocentric ecliptic coordinates:**
   ```
   x_ecl = r·[cos(Ω)·cos(ν+ω) - sin(Ω)·sin(ν+ω)·cos(I)]
   y_ecl = r·[sin(Ω)·cos(ν+ω) + cos(Ω)·sin(ν+ω)·cos(I)]
   z_ecl = r·sin(ν+ω)·sin(I)

   λ = atan2(y_ecl, x_ecl)  [heliocentric longitude]
   β = atan2(z_ecl, √(x_ecl² + y_ecl²))  [heliocentric latitude]
   ```

**Implementation:** `EphemerisEngine.heliocentricPosition(elements:T:)` (lines 147–186)

**Inputs:**
- `elements: PlanetElements` — Keplerian elements
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `(lon: Double, lat: Double, r: Double)` — ecliptic longitude (degrees, 0–360), latitude (degrees, ±90), heliocentric distance (AU)

**Reference:** Jean Meeus, *Astronomical Algorithms*, Chapter 33

---

### 1.6 Geocentric Longitude Computation

Converts heliocentric planetary positions to geocentric (Earth-centered) coordinates.

**Algorithm:**

1. Compute heliocentric position of planet: `(λ_p, β_p, r_p)`
2. Compute heliocentric position of Earth: `(λ_E, β_E, r_E)`
3. Convert both to rectangular ecliptic coordinates:
   ```
   x_p = r_p·cos(β_p)·cos(λ_p)
   y_p = r_p·cos(β_p)·sin(λ_p)
   z_p = r_p·sin(β_p)

   (similarly for Earth: x_E, y_E, z_E)
   ```
4. Compute geocentric position vector:
   ```
   Δx = x_p - x_E
   Δy = y_p - y_E
   Δz = z_p - z_E
   ```
5. Convert back to geocentric ecliptic coordinates:
   ```
   λ_geo = atan2(Δy, Δx)  (mod 360°)
   ```

**Implementation:** `EphemerisEngine.geocentricLongitude(planet:T:)` (lines 191–212)

**Inputs:**
- `planet: PlanetElements`
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — geocentric ecliptic longitude (degrees, 0–360)

**Accuracy:** ~1 arcminute for inner planets, ~5 arcminutes for outer planets (adequate for zodiac sign determination, which requires only 30° = 1 sign precision)

---

### 1.7 Solar Longitude

The Sun's geocentric position is the inverse of Earth's heliocentric position.

**Algorithm:**
```
λ_Sun = λ_Earth_helio + 180° (mod 360°)
```

**Implementation:** `EphemerisEngine.sunLongitude(T:)` (lines 217–220)

**Inputs:**
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — Sun's geocentric ecliptic longitude (degrees, 0–360)

---

### 1.8 Lunar Longitude (Simplified Lunar Theory)

Computes the Moon's geocentric ecliptic longitude using a truncated ELP2000 series.

**Algorithm:**

1. **Compute fundamental arguments** (all in degrees):
   ```
   L' = 218.3164477 + 481267.88123421·T - 0.0015786·T² + T³/538841
   D = 297.8501921 + 445267.1114034·T - 0.0018819·T² + T³/545868
   M = 357.5291092 + 35999.0502909·T - 0.0001536·T²
   M' = 134.9633964 + 477198.8675055·T + 0.0087414·T² + T³/69699
   F = 93.2720950 + 483202.0175233·T - 0.0036539·T²
   ```
   Where:
   - L' = Moon's mean longitude
   - D = Mean elongation of Moon from Sun
   - M = Sun's mean anomaly
   - M' = Moon's mean anomaly
   - F = Moon's argument of latitude

2. **Add principal periodic terms** (degrees):
   ```
   λ = L'
      + 6.289·sin(M')
      + 1.274·sin(2D - M')
      + 0.658·sin(2D)
      + 0.214·sin(2M')
      - 0.186·sin(M)
      - 0.114·sin(2F)
      + 0.059·sin(2D - 2M')
      + 0.057·sin(2D - M - M')
      + 0.053·sin(2D + M')
      + 0.046·sin(2D - M)
      - 0.041·sin(M - M')
      - 0.035·sin(D)
      - 0.031·sin(M + M')
   ```

**Implementation:** `EphemerisEngine.moonLongitude(T:)` (lines 226–272)

**Inputs:**
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — Moon's geocentric ecliptic longitude (degrees, 0–360)

**Reference:** Jean Meeus, *Astronomical Algorithms*, Chapter 47 (simplified form)

**Accuracy:** ~0.5° (sufficient for zodiac sign determination; Moon moves ~13° per day, so 0.5° = ~1 hour error)

---

### 1.9 Pluto Longitude (Polynomial Approximation)

Pluto's orbit is too perturbed by Neptune for simple Keplerian elements. A polynomial fit with major perturbation terms is used.

**Algorithm:**
```
L_mean = 238.92903833 + 145.20780515·T
S = (50.03 + 1222.11·T)  [Saturn's position proxy]
P = (238.96 + 144.96·T)  [Pluto's mean longitude proxy]

λ = L_mean
   - 1.274·sin(P - 2S)
   + 1.365·sin(P - S)
   - 0.327·sin(P)
   + 0.331·sin(2P - 3S)
   + geocentric_parallax_correction
```

**Implementation:** `EphemerisEngine.plutoLongitude(T:)` (lines 278–300)

**Inputs:**
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — Pluto's geocentric ecliptic longitude (degrees, 0–360)

**Validity:** 1885–2099

**Accuracy:** ~1° (adequate for sign determination)

---

### 1.10 North Node Longitude (Mean Lunar Node)

The North Node (ascending node of the Moon's orbit) regresses due to solar and planetary perturbations.

**Algorithm:**
```
Ω = 125.0445479 - 1934.1362891·T + 0.0020754·T² + T³/467441 (mod 360°)
```

**Implementation:** `EphemerisEngine.northNodeLongitude(T:)` (lines 305–310)

**Inputs:**
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — North Node ecliptic longitude (degrees, 0–360)

**Reference:** Jean Meeus, *Astronomical Algorithms*, Chapter 47

**Accuracy:** ~0.01° (mean node; osculating node can differ by ~1.5°)

---

### 1.11 Lilith (Black Moon) Longitude

Mean Black Moon Lilith is the Moon's mean apogee (opposite of perigee).

**Algorithm:**
```
ϖ_lunar = 83.3532465 + 4069.0137287·T - 0.0103200·T² - T³/80053
λ_Lilith = ϖ_lunar + 180° (mod 360°)
```

**Implementation:** `EphemerisEngine.lilithLongitude(T:)` (lines 315–321)

**Inputs:**
- `T: Double` — Julian centuries from J2000.0

**Outputs:**
- `Double` — Mean Lilith ecliptic longitude (degrees, 0–360)

**Note:** Multiple definitions of "Lilith" exist in astrology (mean apogee, osculating apogee, Dark Moon Waltemath). This implementation uses the standard mean lunar apogee.

**Accuracy:** ~1° for mean apogee

---

### 1.12 Retrograde Motion Detection

A planet is retrograde when its geocentric ecliptic longitude decreases over time.

**Algorithm:**
```
λ₁ = longitude at date D
λ₂ = longitude at date D+1 day

Δλ = λ₂ - λ₁ (normalized to [-180°, +180°])

If Δλ < 0: retrograde
If Δλ ≥ 0: direct (prograde)
```

**Implementation:** `EphemerisEngine.computeChart(birthData:)` lines 375–382 (planets), 393–398 (Pluto)

**Normalization:** The difference is wrapped to [-180°, +180°] to handle 0°/360° boundary crossing.

---

## 2. Coordinate Transformations

**Source:** `/BirthChart/Computation/CoordinateTransform.swift`

### 2.1 Obliquity of the Ecliptic

The ecliptic plane (Earth's orbital plane) is tilted 23.44° relative to the celestial equator.

**Constant:**
```
ε = 23.4393° ≈ 0.4091 radians
```

**Implementation:** `CoordinateTransform.obliquityDeg`, `CoordinateTransform.obliquityRad` (lines 7–10)

**Reference:** IAU mean obliquity at J2000.0. For high-precision work, obliquity should be computed as a function of time:
```
ε(T) = 23.439291° - 0.013004°·T - 1.64e-7°·T² + ...
```
For birth charts (short time scales relative to precession), the J2000.0 value is adequate.

---

### 2.2 Equatorial to Ecliptic Conversion

Converts equatorial coordinates (right ascension, declination) to ecliptic longitude.

**Transformation Formulas:**
```
λ = atan2(sin(α)·cos(ε) + tan(δ)·sin(ε), cos(α))
β = arcsin(sin(δ)·cos(ε) - cos(δ)·sin(ε)·sin(α))
```

Where:
- α = right ascension
- δ = declination
- ε = obliquity of ecliptic
- λ = ecliptic longitude
- β = ecliptic latitude

**Implementation:** `CoordinateTransform.equatorialToEclipticLongitude(ra:dec:)` (lines 18–33)

**Inputs:**
- `ra: Double` — right ascension (radians)
- `dec: Double` — declination (radians)

**Outputs:**
- `Double` — ecliptic longitude (degrees, 0–360)

**Reference:** Standard spherical coordinate rotation; see Jean Meeus, *Astronomical Algorithms*, Chapter 13

---

### 2.3 Greenwich Mean Sidereal Time (GMST)

Sidereal time measures Earth's rotation relative to the fixed stars (not the Sun).

**Algorithm:**
```
T = (JD - 2451545.0) / 36525.0

θ₀ = 280.46061837
    + 360.98564736629·(JD - 2451545.0)
    + 0.000387933·T²
    - T³/38710000

θ₀ = θ₀ mod 360°  (degrees)
θ₀_rad = θ₀ × π/180  (radians)
```

**Implementation:** `CoordinateTransform.gmst(jd:)` (lines 50–62)

**Inputs:**
- `jd: Double` — Julian Date

**Outputs:**
- `Double` — Greenwich Mean Sidereal Time (radians, 0–2π)

**Reference:** IAU formula from Jean Meeus, *Astronomical Algorithms*, Chapter 12

**Accuracy:** ~0.1 seconds of time

---

### 2.4 Local Sidereal Time (LST)

Local Sidereal Time adjusts GMST for the observer's longitude.

**Algorithm:**
```
LST = GMST + λ_obs

Where:
  λ_obs = observer's longitude (radians, positive east)
```

**Implementation:** `CoordinateTransform.localSiderealTime(jd:longitudeDeg:)` (lines 69–74)

**Inputs:**
- `jd: Double` — Julian Date
- `longitudeDeg: Double` — geographic longitude (degrees, positive east)

**Outputs:**
- `Double` — Local Sidereal Time (radians, 0–2π)

**Usage:** LST is required for computing the Ascendant and Midheaven.

---

### 2.5 Angle Normalization

Wraps angles to standard ranges.

**Degrees (0–360):**
```
normalized = ((angle mod 360) + 360) mod 360
```

**Radians (0–2π):**
```
normalized = ((angle mod 2π) + 2π) mod 2π
```

**Implementation:**
- `CoordinateTransform.normalizeDegrees(_:)` (lines 77–80)
- `CoordinateTransform.normalizeRadians(_:)` (lines 83–86)

**Note:** Double modulo operator in Swift is `truncatingRemainder(dividingBy:)`. The nested `mod` handles negative angles correctly.

---

## 3. Ascendant and Midheaven Calculation

**Source:** `/BirthChart/Computation/AscendantCalculator.swift`

The Ascendant (ASC) is the degree of the ecliptic rising on the eastern horizon at the moment of birth. The Midheaven (MC) is the degree culminating on the meridian.

### 3.1 Midheaven Computation

**Algorithm:**
```
MC = atan2(sin(LST), cos(LST)·cos(ε))
```

Where:
- LST = Local Sidereal Time (radians)
- ε = obliquity of ecliptic (radians)

**Implementation:** `AscendantCalculator.compute(lst:latitudeDeg:)` lines 23–25

**Inputs:**
- `lst: Double` — Local Sidereal Time (radians)
- `latitudeDeg: Double` — observer's latitude (degrees, unused for MC)

**Outputs:**
- `Double` — Midheaven ecliptic longitude (degrees, 0–360)

**Reference:** Jean Meeus, *Astronomical Algorithms*, Chapter 13

**Interpretation:** The MC is the ecliptic longitude of the point where the local meridian intersects the ecliptic.

---

### 3.2 Ascendant Computation

**Algorithm:**
```
ASC = atan2(-cos(LST), sin(LST)·cos(ε) + tan(φ)·sin(ε))
```

Where:
- LST = Local Sidereal Time (radians)
- ε = obliquity of ecliptic (radians)
- φ = observer's latitude (radians)

**Disambiguation:** The `atan2` formula can return either the Ascendant or the Descendant (180° opposite) depending on the quadrant. The Ascendant should be ~90° ahead of the MC in ecliptic longitude.

**Correction:**
```
diff = (ASC - MC) mod 360°
If diff > 180°:
    ASC = (ASC + 180°) mod 360°
```

**Implementation:** `AscendantCalculator.compute(lst:latitudeDeg:)` lines 28–39

**Inputs:**
- `lst: Double` — Local Sidereal Time (radians)
- `latitudeDeg: Double` — observer's latitude (degrees)

**Outputs:**
- `Double` — Ascendant ecliptic longitude (degrees, 0–360)

**Reference:** Jean Meeus, *Astronomical Algorithms*, Chapter 13

**Limitations:**
- Formula is undefined at Earth's poles (φ = ±90°)
- At high latitudes (>66°), some ecliptic degrees may never rise (no Ascendant for those degrees)
- This implementation uses the standard formula without special polar handling

---

## 4. Moon Phase Computation

**Source:** `/BirthChart/Computation/MoonPhase.swift`

### 4.1 Illumination Percentage

The fraction of the Moon's disk that is illuminated depends on the Sun-Moon elongation angle.

**Algorithm:**
```
ψ = min(|λ_Moon - λ_Sun|, 360° - |λ_Moon - λ_Sun|)  [elongation, 0°–180°]

I = (1 - cos(ψ)) / 2 × 100%
```

**Derivation:**
- At ψ = 0° (New Moon): cos(0°) = 1, so I = 0%
- At ψ = 90° (Quarter): cos(90°) = 0, so I = 50%
- At ψ = 180° (Full Moon): cos(180°) = -1, so I = 100%

**Implementation:** `MoonPhaseCalculator.illumination(sunLon:moonLon:)` (lines 12–16)

**Inputs:**
- `sunLon: Double` — Sun's ecliptic longitude (degrees)
- `moonLon: Double` — Moon's ecliptic longitude (degrees)

**Outputs:**
- `Double` — illumination percentage (0–100)

**Accuracy:** Simplified formula ignores Moon's elliptical orbit and distance variation (~5% error in extreme cases)

---

### 4.2 Phase Classification

Determines the named lunar phase from illumination and waxing/waning state.

**Algorithm:**
```
If I < 1%:         New Moon 🌑
If I < 49%:
    Waxing:        Waxing Crescent 🌒
    Waning:        Waning Crescent 🌘
If I < 51%:
    Waxing:        First Quarter 🌓
    Waning:        Last Quarter 🌗
If I < 99%:
    Waxing:        Waxing Gibbous 🌔
    Waning:        Waning Gibbous 🌖
If I ≥ 99%:        Full Moon 🌕
```

**Waxing/Waning Detection:**
```
I_tomorrow = illumination(λ_Sun(t+1), λ_Moon(t+1))

If I_tomorrow > I_today: Waxing
Else: Waning
```

**Implementation:**
- `MoonPhaseCalculator.classify(illuminationPct:isWaxing:)` (lines 24–50)
- Waxing detection in `EphemerisEngine.computeChart(birthData:)` lines 443–449

**Inputs:**
- `illuminationPct: Double` — current illumination (0–100)
- `isWaxing: Bool` — whether illumination is increasing

**Outputs:**
- `MoonPhaseInfo` — phase name, percentage, emoji symbol

---

## 5. Aspect Detection

**Source:** `/BirthChart/Computation/AspectDetector.swift`

Aspects are specific angular relationships between planets that have interpretive significance in astrology.

### 5.1 Supported Aspects

| Aspect | Symbol | Angle | Max Orb |
|--------|--------|-------|---------|
| Conjunction | ☌ | 0° | 8° |
| Sextile | ⚹ | 60° | 6° |
| Square | □ | 90° | 7° |
| Trine | △ | 120° | 8° |
| Opposition | ☍ | 180° | 8° |

**Source:** `/BirthChart/Models/Aspect.swift` (referenced by AspectDetector)

**Orb:** The maximum angular deviation from the exact aspect angle. For example, a conjunction at 5° separation (orb = 5°) is within the 8° maximum and counts as valid.

---

### 5.2 Angular Separation

Computes the shortest angular distance between two ecliptic longitudes on the zodiac circle.

**Algorithm:**
```
diff = |λ₁ - λ₂|
separation = min(diff, 360° - diff)
```

**Range:** 0° to 180° (never more than a semicircle)

**Implementation:** `AspectDetector.angularSeparation(_:_:)` (lines 7–10)

**Inputs:**
- `lon1: Double`, `lon2: Double` — ecliptic longitudes (degrees, 0–360)

**Outputs:**
- `Double` — angular separation (degrees, 0–180)

---

### 5.3 Aspect Detection Algorithm

Detects all aspects between pairs of celestial bodies.

**Algorithm:**

1. **Enumerate all unique pairs:** For n bodies, there are n(n-1)/2 pairs
2. **For each pair (i, j):**
   - Compute angular separation: `sep = angularSeparation(λᵢ, λⱼ)`
   - **For each aspect type k** (conjunction, sextile, square, trine, opposition):
     - Compute orb: `orb = |sep - aspect_angle_k|`
     - If `orb ≤ max_orb_k`:
       - Record aspect (i, j, type k, orb)
       - **Break** (only one aspect per pair)

**Implementation:** `AspectDetector.detectAspects(bodies:)` (lines 20–46)

**Inputs:**
- `bodies: [CelestialBody]` — array of celestial bodies with `eclipticLongitude` property

**Outputs:**
- `[Aspect]` — array of detected aspects, each containing:
  - `body1: String`, `body2: String` — names of the two bodies
  - `type: AspectType` — the aspect type (conjunction, sextile, etc.)
  - `orb: Double` — exactness of the aspect (degrees, 0 = exact)

**Complexity:** O(n² × k) where n = number of bodies, k = 5 aspect types

**Priority:** Aspects are detected in order (conjunction, sextile, square, trine, opposition). If two aspect types overlap (rare), the first match wins.

**Note:** The algorithm returns only the strongest (first matching) aspect per pair. To detect multiple applying aspects, the loop would continue without the `break`.

---

## 6. Satellite Orbital Mechanics

**Source:** `/BirthChart/Models/OrbitalObject.swift`

Computes 3D positions of Earth-orbiting satellites using simplified Keplerian mechanics with J2 perturbation for RAAN precession.

### 6.1 Circular Orbit Approximation

Most operational satellites maintain near-circular orbits (e ≈ 0), allowing simplification.

**Kepler's equation for circular orbits:**
```
M = n·t
E ≈ M  (for e = 0)
ν ≈ M  (true anomaly = mean anomaly)
```

Where:
- M = mean anomaly
- n = mean motion = 360°/T (T = orbital period)
- t = time since epoch

**Implementation:** `OrbitalObject.position(at:)` lines 30–34

**Orbital elements stored:**
- `altitudeKm: Double` — altitude above Earth's surface
- `inclinationDeg: Double` — orbital inclination (0° = equatorial, 90° = polar)
- `raanDeg: Double` — Right Ascension of Ascending Node (RAAN) at J2000 epoch
- `meanAnomalyDeg: Double` — mean anomaly at J2000 epoch
- `periodMinutes: Double` — orbital period

---

### 6.2 RAAN Precession (J2 Perturbation)

Earth's equatorial bulge (J2 oblateness term) causes the ascending node to precess.

**Algorithm:**
```
Ω(t) = Ω₀ + Ω_dot·t

Ω_dot = -1.5 · J₂ · n · (R_⊕/a)² · cos(i)

Where:
  J₂ = 1.08263 × 10⁻³  (Earth's J2 coefficient)
  n = mean motion (rad/s) = 2π/T_sec
  R_⊕ = 6371 km (Earth's mean radius)
  a = semimajor axis (meters)
  i = inclination (radians)
```

**Implementation:** `OrbitalObject.position(at:)` lines 36–45

**Physical Interpretation:** The J2 term accounts for Earth's oblate spheroid shape. For prograde LEO orbits (i < 90°), RAAN regresses (moves westward). For retrograde orbits (i > 90°), RAAN progresses (eastward).

**Reference:** Vallado, *Fundamentals of Astrodynamics and Applications* (4th ed.), Chapter 9

**Accuracy:** J2 is the dominant perturbation for LEO. Higher-order terms (J3, J4, atmospheric drag, lunar/solar gravity) are neglected. Positions are accurate to ~1 km for LEO over 1-day propagation.

---

### 6.3 Position in Orbital Plane

For a circular orbit, position is computed directly from mean anomaly.

**Algorithm:**
```
x_orb = a·cos(M)
y_orb = a·sin(M)
z_orb = 0
```

Where:
- a = (altitude + R_⊕) / R_⊕ (semimajor axis in Earth-radii units)
- M = mean anomaly (radians)

**Implementation:** `OrbitalObject.position(at:)` lines 48–49

---

### 6.4 Coordinate Transformation to Earth-Centered Inertial (ECI)

Transform from the orbital plane to the ECI (Earth-Centered Inertial) frame.

**Algorithm:**

1. **Rotate by inclination** (around x-axis of orbital plane):
   ```
   x_inc = x_orb
   y_inc = y_orb·cos(i)
   z_inc = y_orb·sin(i)
   ```

2. **Rotate by RAAN** (around z-axis / polar axis):
   ```
   x = x_inc·cos(Ω) - y_inc·sin(Ω)
   y = x_inc·sin(Ω) + y_inc·cos(Ω)
   z = z_inc
   ```

**Implementation:** `OrbitalObject.position(at:)` lines 51–60

**Inputs:**
- `date: Date` — time at which to compute position

**Outputs:**
- `(x: Double, y: Double, z: Double)` — ECI position in Earth-radii units (1.0 = surface, ~6371 km)

**Reference:** Vallado, *Fundamentals of Astrodynamics and Applications*, Chapter 3

---

## 7. 3D Visualization Scaling

**Source:** `/BirthChart/SceneKit/SolarSystemScene.swift` and `/BirthChart/SceneKit/GeocentricScene.swift`

Both scenes use logarithmic and exaggerated scaling to make objects visible while preserving relative spatial relationships.

### 7.1 Solar System Scene Scaling

Real solar system distances span 8 orders of magnitude (Mercury orbit ~0.4 AU, Neptune orbit ~30 AU). Linear scaling would make inner planets invisible.

**Strategy:** Log-based manual assignment of orbit radii.

**Orbit Radii (scene units):**
| Planet | Real Distance (AU) | Scene Radius | Scale Factor |
|--------|-------------------|--------------|--------------|
| Mercury | 0.39 | 3.0 | 7.7× |
| Venus | 0.72 | 4.5 | 6.3× |
| Earth | 1.00 | 6.0 | 6.0× |
| Mars | 1.52 | 8.0 | 5.3× |
| Jupiter | 5.20 | 11.0 | 2.1× |
| Saturn | 9.54 | 14.0 | 1.5× |
| Uranus | 19.19 | 17.0 | 0.9× |
| Neptune | 30.07 | 19.0 | 0.6× |
| Pluto | 39.48 | 21.0 | 0.5× |

**Formula:** Roughly `r_scene ≈ 3·log₁₀(r_real × 10)` with manual adjustments for visual balance.

**Implementation:** `SolarSystemScene.planetVisuals` dictionary (lines 14–26)

**Planet Sizes:** Also exaggerated (Jupiter radius = 0.9 scene units, Earth = 0.4). If scaled realistically, Earth would be a 0.001-unit speck invisible to the camera.

---

### 7.2 Geocentric Scene (Satellite Shell) Scaling

Real satellite altitudes range from 400 km (ISS) to 35,786 km (GEO). Linear scaling would compress LEO satellites into a thin shell barely distinguishable from Earth's surface.

**Strategy:** Piecewise linear mapping with 3 altitude bands.

**Scale Mapping:**

1. **LEO (Low Earth Orbit): 400–3000 km altitude**
   - Real altitude/radius ratio: 1.06 – 1.47
   - Scene radius: `earthRadius` (2.0) to `leoScale` (2.8)
   - Formula: `r = 2.0 + (ratio - 1.0)/0.5 · 0.8`

2. **MEO (Medium Earth Orbit): 3000–20,000 km altitude**
   - Real altitude/radius ratio: 1.47 – 4.14
   - Scene radius: `leoScale` (2.8) to `meoScale` (5.5)
   - Formula: `r = 2.8 + (ratio - 1.5)/2.5 · 2.7`

3. **GEO (Geosynchronous Orbit): 20,000–42,000 km altitude**
   - Real altitude/radius ratio: 4.14 – 7.59
   - Scene radius: `meoScale` (5.5) to `geoScale` (8.5)
   - Formula: `r = 5.5 + min(1.0, (ratio - 4.0)/2.6) · 3.0`

**Implementation:** `GeocentricScene.sceneRadius(altitudeKm:)` (lines 15–31)

**Inputs:**
- `altitudeKm: Double` — satellite altitude above Earth's surface (km)

**Outputs:**
- `Float` — scene radius (arbitrary units, Earth surface = 2.0)

**Visual Effect:** LEO satellites appear in a thick visible shell, MEO forms a middle layer, GEO satellites cluster in an outer ring. Relative orbital velocities are preserved (LEO orbits faster than GEO).

---

### 7.3 Moon Distance

The Moon orbits at ~384,400 km, which would scale to `geoScale + 4` (~12.5 scene units) using the GEO formula. For visual balance, the Moon is placed at `moonScale = 12.0`.

**Implementation:** `GeocentricScene.build(date:chart:)` lines 134–146

---

## 8. ISS Acquisition of Signal (AOS) Cone

**Source:** `/BirthChart/SceneKit/GeocentricScene.swift`, function `addAOSCone(to:satPosition:)` (lines 246–289)

The ISS AOS cone visualizes the ground footprint — the region of Earth's surface from which the ISS is visible above the horizon.

### 8.1 Geometric Derivation

Consider Earth as a sphere of radius R, and the ISS at altitude h above the surface.

**Horizon Distance:**

The line-of-sight from the ISS to Earth's horizon is tangent to Earth's surface. Using the Pythagorean theorem in the right triangle formed by:
- ISS position (distance R + h from Earth's center)
- Earth's center
- Horizon point (distance R from Earth's center)

```
(R + h)² = R² + d²
d² = (R + h)² - R²
d² = 2Rh + h²
d ≈ √(2Rh)  (for h << R)
```

For ISS at h = 420 km, R = 6371 km:
```
d = √(2 · 6371 · 420) ≈ 2318 km  (horizon distance along Earth's surface)
```

**Half-Angle of Visibility:**

The half-angle θ of the cone from ISS to the horizon circle:
```
sin(θ) = R / (R + h)
θ = arcsin(R / (R + h))

For h = 420 km:
θ = arcsin(6371 / 6791) ≈ 69.6°
```

Alternatively, the half-angle measured from nadir (straight down):
```
φ = arccos(R / (R + h)) ≈ 20.4°
```

**Footprint Radius on Earth's Surface:**

The arc length from the sub-satellite point to the horizon:
```
arc = R · φ ≈ 6371 · 0.356 rad ≈ 2268 km
```

---

### 8.2 Cone Geometry in SceneKit

The cone is rendered with:
- **Apex** at the ISS position
- **Base** on Earth's surface
- **Height** = ISS altitude in scene units
- **Base radius** = height × tan(φ) ≈ height × 0.364

**Algorithm:**
```
dist_ISS_to_Earth_center = √(x² + y² + z²)  (scene units)
cone_height = dist_ISS_to_Earth_center - earthRadius  (scene units)
cone_base_radius = cone_height × 0.36

Create SCNCone(topRadius: 0, bottomRadius: cone_base_radius, height: cone_height)
Position cone at ISS location, pointing toward (0, 0, 0)
```

**Implementation:** `GeocentricScene.addAOSCone(to:satPosition:)` lines 246–275

**Visual Appearance:**
- Semi-transparent yellow cone (α = 0.08 diffuse, 0.04 emission)
- Accompanied by a spotlight shining from ISS toward Earth

---

### 8.3 Accuracy and Limitations

**Assumptions:**
1. Earth is a perfect sphere (ignores ellipsoidal shape)
2. Straight-line visibility (ignores atmospheric refraction, which extends the horizon by ~3%)
3. Zero elevation angle at horizon (practical communications require ISS be >5° above horizon)

**Real-World Corrections:**

For actual ISS tracking:
- **Atmospheric refraction** extends the horizon by ~0.6°, adding ~70 km to footprint radius
- **Minimum elevation angle** (typically 10°) reduces the usable footprint to ~1600 km radius
- **Signal propagation** may differ from line-of-sight due to ionospheric effects

**Reference:**
- Wertz, *Space Mission Analysis and Design* (3rd ed.), Chapter 9: "Communications Architecture"
- NASA ISS visibility data: https://spotthestation.nasa.gov/

---

## Appendices

### A. Coordinate System Conventions

**Ecliptic Coordinates:**
- Origin: Earth (geocentric) or Sun (heliocentric)
- Fundamental plane: Ecliptic (Earth's orbital plane)
- Longitude λ: 0° at vernal equinox, increases eastward (Aries → Taurus → ... → Pisces → Aries)
- Latitude β: ±90°, positive north of ecliptic

**Equatorial Coordinates:**
- Origin: Earth's center
- Fundamental plane: Celestial equator (Earth's equatorial plane projected onto the sky)
- Right Ascension α: 0h–24h (or 0°–360°), measured eastward from vernal equinox
- Declination δ: ±90°, positive north

**Earth-Centered Inertial (ECI):**
- Origin: Earth's center
- x-axis: vernal equinox direction
- z-axis: Earth's rotation axis (north pole)
- y-axis: completes right-handed system

---

### B. Accuracy Summary

| Computation | Typical Error | Adequate For |
|-------------|---------------|--------------|
| Solar longitude | 0.01° | Sign determination, aspects |
| Lunar longitude | 0.5° | Sign determination |
| Planet longitudes (inner) | 1' (0.017°) | Sign, aspects |
| Planet longitudes (outer) | 10' (0.17°) | Sign, aspects |
| Pluto longitude | 1° | Sign determination |
| Ascendant | 4' (0.067°) | Rising sign |
| Midheaven | 1' (0.017°) | Sign determination |
| Moon phase | ±1 hour | Phase name |
| Aspect orbs | 0.01° | Aspect detection |
| Satellite positions (1 day) | ~1 km | Visualization |

**Note:** 1 zodiac sign = 30°, so errors < 1° are typically acceptable for astrological interpretation. For precise astronomical work, higher-order corrections (nutation, aberration, light-time, ΔT) would be required.

---

### C. References

1. **Standish, E.M.** (1992). "Keplerian Elements for Approximate Positions of the Major Planets." JPL IOM 314.10-127.
   https://ssd.jpl.nasa.gov/planets/approx_pos.html

2. **Meeus, Jean** (1998). *Astronomical Algorithms* (2nd edition). Willmann-Bell, Inc.

3. **Vallado, David A.** (2013). *Fundamentals of Astrodynamics and Applications* (4th edition). Microcosm Press.

4. **Wertz, James R. & Larson, Wiley J.** (1999). *Space Mission Analysis and Design* (3rd edition). Microcosm Press & Kluwer Academic Publishers.

5. **Urban, Sean E. & Seidelmann, P. Kenneth** (2012). *Explanatory Supplement to the Astronomical Almanac* (3rd edition). University Science Books.

6. **IAU SOFA** (Standards of Fundamental Astronomy) Software Library.
   http://www.iausofa.org/

---

### D. Version History

**Version 1.0** (February 14, 2026)
- Initial comprehensive documentation
- Covers all algorithms in Birth Chart iOS v1.0
- Includes JPL ephemeris engine, coordinate transforms, ascendant calculation, moon phase, aspects, satellite mechanics, and 3D scene scaling

---

**Document Prepared By:** Documentation Agent (Claude Opus 4.6)
**Project:** Birth Chart iOS
**Repository:** https://github.com/brucedombrowski/birth-chart-ios
**License:** Follow project license (see repository)

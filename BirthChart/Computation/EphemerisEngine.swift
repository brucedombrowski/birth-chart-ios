import Foundation

// MARK: - Orbital Elements (JPL Keplerian Elements for Approximate Positions)

/// Keplerian orbital elements at J2000.0 and their rates per Julian century.
/// Source: Standish (1992), "Keplerian Elements for Approximate Positions of the Major Planets"
/// Valid for 1800–2050 CE.
struct PlanetElements {
    let a: Double       // semi-major axis (AU)
    let aDot: Double    // rate (AU/century)
    let e: Double       // eccentricity
    let eDot: Double    // rate (/century)
    let I: Double       // inclination (degrees)
    let IDot: Double    // rate (degrees/century)
    let L: Double       // mean longitude (degrees)
    let LDot: Double    // rate (degrees/century)
    let wBar: Double    // longitude of perihelion (degrees)
    let wBarDot: Double // rate (degrees/century)
    let omega: Double   // longitude of ascending node (degrees)
    let omegaDot: Double // rate (degrees/century)
}

/// JPL orbital elements for all planets.
enum OrbitalElements {

    static let mercury = PlanetElements(
        a: 0.38709927, aDot: 0.00000037,
        e: 0.20563593, eDot: 0.00001906,
        I: 7.00497902, IDot: -0.00594749,
        L: 252.25032350, LDot: 149472.67411175,
        wBar: 77.45779628, wBarDot: 0.16047689,
        omega: 48.33076593, omegaDot: -0.12534081
    )

    static let venus = PlanetElements(
        a: 0.72333566, aDot: 0.00000390,
        e: 0.00677672, eDot: -0.00004107,
        I: 3.39467605, IDot: -0.00078890,
        L: 181.97909950, LDot: 58517.81538729,
        wBar: 131.60246718, wBarDot: 0.00268329,
        omega: 76.67984255, omegaDot: -0.27769418
    )

    static let earth = PlanetElements(
        a: 1.00000261, aDot: 0.00000562,
        e: 0.01671123, eDot: -0.00004392,
        I: -0.00001531, IDot: -0.01294668,
        L: 100.46457166, LDot: 35999.37244981,
        wBar: 102.93768193, wBarDot: 0.32327364,
        omega: 0.0, omegaDot: 0.0
    )

    static let mars = PlanetElements(
        a: 1.52371034, aDot: 0.00001847,
        e: 0.09339410, eDot: 0.00007882,
        I: 1.84969142, IDot: -0.00813131,
        L: -4.55343205, LDot: 19140.30268499,
        wBar: -23.94362959, wBarDot: 0.44441088,
        omega: 49.55953891, omegaDot: -0.29257343
    )

    static let jupiter = PlanetElements(
        a: 5.20288700, aDot: -0.00011607,
        e: 0.04838624, eDot: -0.00013253,
        I: 1.30439695, IDot: -0.00183714,
        L: 34.39644051, LDot: 3034.74612775,
        wBar: 14.72847983, wBarDot: 0.21252668,
        omega: 100.47390909, omegaDot: 0.20469106
    )

    static let saturn = PlanetElements(
        a: 9.53667594, aDot: -0.00125060,
        e: 0.05386179, eDot: -0.00050991,
        I: 2.48599187, IDot: 0.00193609,
        L: 49.95424423, LDot: 1222.49362201,
        wBar: 92.59887831, wBarDot: -0.41897216,
        omega: 113.66242448, omegaDot: -0.28867794
    )

    static let uranus = PlanetElements(
        a: 19.18916464, aDot: -0.00196176,
        e: 0.04725744, eDot: -0.00004397,
        I: 0.77263783, IDot: -0.00242939,
        L: 313.23810451, LDot: 428.48202785,
        wBar: 170.95427630, wBarDot: 0.40805281,
        omega: 74.01692503, omegaDot: 0.04240589
    )

    static let neptune = PlanetElements(
        a: 30.06992276, aDot: 0.00026291,
        e: 0.00859048, eDot: 0.00005105,
        I: 1.77004347, IDot: 0.00035372,
        L: -55.12002969, LDot: 218.45945325,
        wBar: 44.96476227, wBarDot: -0.32241464,
        omega: 131.78422574, omegaDot: -0.00508664
    )

    /// All planet elements indexed by name (excluding Sun, Moon, Pluto which use special methods).
    static let allPlanets: [(String, PlanetElements)] = [
        ("Mercury", mercury),
        ("Venus", venus),
        ("Earth", earth),
        ("Mars", mars),
        ("Jupiter", jupiter),
        ("Saturn", saturn),
        ("Uranus", uranus),
        ("Neptune", neptune),
    ]
}

// MARK: - Ephemeris Engine

/// Pure-Swift ephemeris engine using Keplerian orbital elements.
///
/// Computes geocentric ecliptic longitudes for all solar system bodies.
/// Based on JPL's "Approximate Positions of the Major Planets" method.
enum EphemerisEngine {

    /// Solve Kepler's equation M = E - e·sin(E) for eccentric anomaly E.
    ///
    /// Uses Newton-Raphson iteration. Converges in 3–5 iterations for
    /// planetary eccentricities.
    ///
    /// - Parameters:
    ///   - M: Mean anomaly in radians
    ///   - e: Orbital eccentricity
    /// - Returns: Eccentric anomaly in radians
    static func solveKepler(M: Double, e: Double) -> Double {
        var E = M + e * sin(M) * (1.0 + e * cos(M))  // initial guess

        for _ in 0..<50 {
            let dE = (E - e * sin(E) - M) / (1.0 - e * cos(E))
            E -= dE
            if abs(dE) < 1e-12 { break }
        }

        return E
    }

    /// Compute heliocentric ecliptic coordinates (longitude, latitude, radius)
    /// for a planet at a given Julian century T from J2000.0.
    ///
    /// - Parameters:
    ///   - elements: Keplerian orbital elements
    ///   - T: Julian centuries from J2000.0
    /// - Returns: (ecliptic longitude in degrees, ecliptic latitude in degrees, radius in AU)
    static func heliocentricPosition(elements el: PlanetElements, T: Double) -> (lon: Double, lat: Double, r: Double) {
        // Compute elements at epoch
        let a = el.a + el.aDot * T
        let e = el.e + el.eDot * T
        let I = (el.I + el.IDot * T) * .pi / 180
        let L = CoordinateTransform.normalizeDegrees(el.L + el.LDot * T)
        let wBar = CoordinateTransform.normalizeDegrees(el.wBar + el.wBarDot * T)
        let omega = CoordinateTransform.normalizeDegrees(el.omega + el.omegaDot * T)

        // Argument of perihelion
        let w = (wBar - omega) * .pi / 180

        // Mean anomaly
        let M = CoordinateTransform.normalizeRadians((L - wBar) * .pi / 180)

        // Solve Kepler's equation for eccentric anomaly
        let E = solveKepler(M: M, e: e)

        // True anomaly
        let xPrime = a * (cos(E) - e)
        let yPrime = a * sqrt(1 - e * e) * sin(E)

        // Heliocentric coordinates in the orbital plane
        let r = sqrt(xPrime * xPrime + yPrime * yPrime)
        let v = atan2(yPrime, xPrime)

        // Transform to ecliptic coordinates
        let omegaRad = omega * .pi / 180

        let xEcl = r * (cos(omegaRad) * cos(v + w)
                       - sin(omegaRad) * sin(v + w) * cos(I))
        let yEcl = r * (sin(omegaRad) * cos(v + w)
                       + cos(omegaRad) * sin(v + w) * cos(I))
        let zEcl = r * sin(v + w) * sin(I)

        let lon = atan2(yEcl, xEcl) * 180 / .pi
        let lat = atan2(zEcl, sqrt(xEcl * xEcl + yEcl * yEcl)) * 180 / .pi

        return (CoordinateTransform.normalizeDegrees(lon), lat, r)
    }

    /// Compute geocentric ecliptic longitude for a planet.
    ///
    /// Subtracts Earth's heliocentric position to get the geocentric view.
    static func geocentricLongitude(planet: PlanetElements, T: Double) -> Double {
        let planetPos = heliocentricPosition(elements: planet, T: T)
        let earthPos = heliocentricPosition(elements: OrbitalElements.earth, T: T)

        // Convert to rectangular ecliptic coordinates
        let planetX = planetPos.r * cos(planetPos.lat * .pi / 180) * cos(planetPos.lon * .pi / 180)
        let planetY = planetPos.r * cos(planetPos.lat * .pi / 180) * sin(planetPos.lon * .pi / 180)
        let planetZ = planetPos.r * sin(planetPos.lat * .pi / 180)

        let earthX = earthPos.r * cos(earthPos.lat * .pi / 180) * cos(earthPos.lon * .pi / 180)
        let earthY = earthPos.r * cos(earthPos.lat * .pi / 180) * sin(earthPos.lon * .pi / 180)
        let earthZ = earthPos.r * sin(earthPos.lat * .pi / 180)

        // Geocentric position
        let dx = planetX - earthX
        let dy = planetY - earthY
        // dz used for latitude (not needed for longitude)
        _ = planetZ - earthZ

        let geoLon = atan2(dy, dx) * 180 / .pi
        return CoordinateTransform.normalizeDegrees(geoLon)
    }

    /// Compute the Sun's geocentric ecliptic longitude.
    ///
    /// The Sun's geocentric position is 180° from Earth's heliocentric longitude.
    static func sunLongitude(T: Double) -> Double {
        let earthPos = heliocentricPosition(elements: OrbitalElements.earth, T: T)
        return CoordinateTransform.normalizeDegrees(earthPos.lon + 180)
    }

    /// Compute the Moon's geocentric ecliptic longitude using a simplified lunar theory.
    ///
    /// This is a low-precision formula (~0.5° accuracy) suitable for sign determination.
    /// Based on Meeus, Astronomical Algorithms, Chapter 47 (simplified).
    static func moonLongitude(T: Double) -> Double {
        // Fundamental arguments (degrees)
        let Lp = CoordinateTransform.normalizeDegrees(
            218.3164477 + 481267.88123421 * T
            - 0.0015786 * T * T + T * T * T / 538841.0
        )
        let D = CoordinateTransform.normalizeDegrees(
            297.8501921 + 445267.1114034 * T
            - 0.0018819 * T * T + T * T * T / 545868.0
        )
        let M = CoordinateTransform.normalizeDegrees(
            357.5291092 + 35999.0502909 * T
            - 0.0001536 * T * T
        )
        let Mp = CoordinateTransform.normalizeDegrees(
            134.9633964 + 477198.8675055 * T
            + 0.0087414 * T * T + T * T * T / 69699.0
        )
        let F = CoordinateTransform.normalizeDegrees(
            93.2720950 + 483202.0175233 * T
            - 0.0036539 * T * T
        )

        // Convert to radians for trig
        let Dr = D * .pi / 180
        let Mr = M * .pi / 180
        let Mpr = Mp * .pi / 180
        let Fr = F * .pi / 180

        // Principal terms of lunar longitude (degrees)
        var longitude = Lp
        longitude += 6.289 * sin(Mpr)
        longitude += 1.274 * sin(2 * Dr - Mpr)
        longitude += 0.658 * sin(2 * Dr)
        longitude += 0.214 * sin(2 * Mpr)
        longitude -= 0.186 * sin(Mr)
        longitude -= 0.114 * sin(2 * Fr)
        longitude += 0.059 * sin(2 * Dr - 2 * Mpr)
        longitude += 0.057 * sin(2 * Dr - Mr - Mpr)
        longitude += 0.053 * sin(2 * Dr + Mpr)
        longitude += 0.046 * sin(2 * Dr - Mr)
        longitude -= 0.041 * sin(Mr - Mpr)
        longitude -= 0.035 * sin(Dr)
        longitude -= 0.031 * sin(Mr + Mpr)

        return CoordinateTransform.normalizeDegrees(longitude)
    }

    /// Compute Pluto's approximate geocentric ecliptic longitude.
    ///
    /// Uses a simplified polynomial fit. Pluto's orbit is too irregular for
    /// simple Keplerian elements; this provides ~1° accuracy for 1885–2099.
    static func plutoLongitude(T: Double) -> Double {
        // Approximate mean longitude of Pluto
        let L = CoordinateTransform.normalizeDegrees(
            238.92903833 + 145.20780515 * T
        )

        // Major perturbation terms from Jupiter and Saturn
        let S = (50.03 + 1222.11 * T) * .pi / 180
        let P = (238.96 + 144.96 * T) * .pi / 180

        var lon = L
        lon += -1.274 * sin(P - 2 * S)
        lon += 1.365 * sin(P - S)
        lon += -0.327 * sin(P)
        lon += 0.331 * sin(2 * P - 3 * S)

        // Geocentric correction (approximate)
        let earthPos = heliocentricPosition(elements: OrbitalElements.earth, T: T)
        let parallax = (1.0 / 39.5) * sin((earthPos.lon - lon) * .pi / 180)
        lon += parallax * 180 / .pi

        return CoordinateTransform.normalizeDegrees(lon)
    }

    /// Compute the Mean North Node longitude (Ω).
    ///
    /// Meeus, Astronomical Algorithms.
    static func northNodeLongitude(T: Double) -> Double {
        CoordinateTransform.normalizeDegrees(
            125.0445479 - 1934.1362891 * T
            + 0.0020754 * T * T + T * T * T / 467441.0
        )
    }

    /// Compute Mean Black Moon Lilith longitude (mean lunar apogee).
    ///
    /// The standard formula gives the mean perigee; Lilith is the apogee (+180°).
    static func lilithLongitude(T: Double) -> Double {
        let perigee = CoordinateTransform.normalizeDegrees(
            83.3532465 + 4069.0137287 * T
            - 0.0103200 * T * T - T * T * T / 80053.0
        )
        return CoordinateTransform.normalizeDegrees(perigee + 180)
    }

    // MARK: - Full Chart Computation

    /// Compute a complete birth chart.
    ///
    /// - Parameter birthData: Observer parameters (date, location, timezone)
    /// - Returns: Complete birth chart result
    static func computeChart(birthData: BirthData) -> BirthChartResult {
        let utcDate = birthData.utcDate
        let jd = CoordinateTransform.julianDate(from: utcDate)
        let T = CoordinateTransform.julianCenturies(fromJD: jd)

        // Tomorrow for retrograde/phase detection
        let jdTomorrow = jd + 1.0
        let tTomorrow = CoordinateTransform.julianCenturies(fromJD: jdTomorrow)

        // --- Sun ---
        let sunLon = sunLongitude(T: T)

        // --- Moon ---
        let moonLon = moonLongitude(T: T)

        // --- Planets ---
        let planetDefs: [(String, PlanetElements)] = [
            ("Mercury", OrbitalElements.mercury),
            ("Venus", OrbitalElements.venus),
            ("Mars", OrbitalElements.mars),
            ("Jupiter", OrbitalElements.jupiter),
            ("Saturn", OrbitalElements.saturn),
            ("Uranus", OrbitalElements.uranus),
            ("Neptune", OrbitalElements.neptune),
        ]

        var bodies: [CelestialBody] = []
        var eclLons: [String: Double] = [:]

        // Sun (never retrograde)
        let sunSign = ZodiacSign.from(longitude: sunLon)
        bodies.append(CelestialBody(
            name: "Sun", sign: sunSign.sign, degreeInSign: sunSign.degree,
            eclipticLongitude: sunLon, isRetrograde: false
        ))
        eclLons["Sun"] = sunLon

        // Moon (never retrograde)
        let moonSign = ZodiacSign.from(longitude: moonLon)
        bodies.append(CelestialBody(
            name: "Moon", sign: moonSign.sign, degreeInSign: moonSign.degree,
            eclipticLongitude: moonLon, isRetrograde: false
        ))
        eclLons["Moon"] = moonLon

        // Planets Mercury–Neptune
        for (name, elements) in planetDefs {
            let lon = geocentricLongitude(planet: elements, T: T)
            let lonTomorrow = geocentricLongitude(planet: elements, T: tTomorrow)

            var motion = lonTomorrow - lon
            if motion > 180 { motion -= 360 }
            else if motion < -180 { motion += 360 }
            let retrograde = motion < 0

            let signInfo = ZodiacSign.from(longitude: lon)
            bodies.append(CelestialBody(
                name: name, sign: signInfo.sign, degreeInSign: signInfo.degree,
                eclipticLongitude: lon, isRetrograde: retrograde
            ))
            eclLons[name] = lon
        }

        // Pluto
        let plutoLon = plutoLongitude(T: T)
        let plutoLonTomorrow = plutoLongitude(T: tTomorrow)
        var plutoMotion = plutoLonTomorrow - plutoLon
        if plutoMotion > 180 { plutoMotion -= 360 }
        else if plutoMotion < -180 { plutoMotion += 360 }
        let plutoSign = ZodiacSign.from(longitude: plutoLon)
        bodies.append(CelestialBody(
            name: "Pluto", sign: plutoSign.sign, degreeInSign: plutoSign.degree,
            eclipticLongitude: plutoLon, isRetrograde: plutoMotion < 0
        ))
        eclLons["Pluto"] = plutoLon

        // --- ASC & MC ---
        let lst = CoordinateTransform.localSiderealTime(
            jd: jd, longitudeDeg: birthData.longitude
        )
        let (ascDeg, mcDeg) = AscendantCalculator.compute(
            lst: lst, latitudeDeg: birthData.latitude
        )

        let ascSign = ZodiacSign.from(longitude: ascDeg)
        let ascendant = CelestialBody(
            name: "Ascendant", sign: ascSign.sign, degreeInSign: ascSign.degree,
            eclipticLongitude: ascDeg, isRetrograde: false
        )

        let mcSign = ZodiacSign.from(longitude: mcDeg)
        let midheaven = CelestialBody(
            name: "Midheaven", sign: mcSign.sign, degreeInSign: mcSign.degree,
            eclipticLongitude: mcDeg, isRetrograde: false
        )

        // --- North Node ---
        let nodeLon = northNodeLongitude(T: T)
        let nodeSign = ZodiacSign.from(longitude: nodeLon)
        let northNode = CelestialBody(
            name: "N Node", sign: nodeSign.sign, degreeInSign: nodeSign.degree,
            eclipticLongitude: nodeLon, isRetrograde: false
        )

        // --- Lilith ---
        let lilithLon = lilithLongitude(T: T)
        let lilithSign = ZodiacSign.from(longitude: lilithLon)
        let lilith = CelestialBody(
            name: "Lilith", sign: lilithSign.sign, degreeInSign: lilithSign.degree,
            eclipticLongitude: lilithLon, isRetrograde: false
        )

        // --- Moon Phase ---
        let illumination = MoonPhaseCalculator.illumination(sunLon: sunLon, moonLon: moonLon)
        let moonLonTomorrow = moonLongitude(T: tTomorrow)
        let sunLonTomorrow = sunLongitude(T: tTomorrow)
        let illumTomorrow = MoonPhaseCalculator.illumination(
            sunLon: sunLonTomorrow, moonLon: moonLonTomorrow
        )
        let moonPhase = MoonPhaseCalculator.classify(
            illuminationPct: illumination, isWaxing: illumTomorrow > illumination
        )

        // --- Aspects ---
        let aspects = AspectDetector.detectAspects(bodies: bodies)

        // --- Elements & Modalities ---
        var elements: [Element: [String]] = [:]
        var modalities: [Modality: [String]] = [:]
        for el in Element.allCases { elements[el] = [] }
        for mod in Modality.allCases { modalities[mod] = [] }

        for body in bodies {
            elements[body.sign.element]?.append(body.name)
            modalities[body.sign.modality]?.append(body.name)
        }

        let dominantElement = elements.max(by: { $0.value.count < $1.value.count })!.key
        let dominantModality = modalities.max(by: { $0.value.count < $1.value.count })!.key

        return BirthChartResult(
            planets: bodies,
            ascendant: ascendant,
            midheaven: midheaven,
            northNode: northNode,
            lilith: lilith,
            moonPhase: moonPhase,
            aspects: aspects,
            elements: elements,
            modalities: modalities,
            dominantElement: dominantElement,
            dominantModality: dominantModality
        )
    }
}

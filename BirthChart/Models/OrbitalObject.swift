import Foundation

/// A satellite or orbital object with Keplerian orbital elements.
struct OrbitalObject: Identifiable, Codable {
    let id: String
    let name: String
    let constellation: String?
    let orbitType: String           // "LEO", "MEO", "GEO"
    let altitudeKm: Double
    let inclinationDeg: Double
    let raanDeg: Double             // Right Ascension of Ascending Node
    let meanAnomalyDeg: Double      // Mean anomaly at J2000 epoch
    let periodMinutes: Double
    let icon: String
    let detail: String
    let launchYear: Int?            // Year satellite was launched (nil = always visible)

    /// Compute 3D position at a given date using simplified Keplerian mechanics.
    /// Returns (x, y, z) in Earth-radii units (1.0 = Earth surface).
    func position(at date: Date) -> (x: Double, y: Double, z: Double) {
        let earthRadiusKm = 6371.0
        let semiMajorAxis = (altitudeKm + earthRadiusKm) / earthRadiusKm

        // Time since J2000 epoch in minutes
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                   timeZone: TimeZone(identifier: "UTC"),
                                   year: 2000, month: 1, day: 1,
                                   hour: 12, minute: 0, second: 0).date!
        let minutesSinceEpoch = date.timeIntervalSince(j2000) / 60.0

        // Mean anomaly at given time (circular orbit)
        let meanMotion = 360.0 / periodMinutes  // degrees per minute
        let M = (meanAnomalyDeg + meanMotion * minutesSinceEpoch)
            .truncatingRemainder(dividingBy: 360)
        let mRad = M * .pi / 180

        // RAAN precession (simplified J2 perturbation for LEO realism)
        let j2 = 1.08263e-3
        let n = 2.0 * .pi / (periodMinutes * 60.0) // rad/s
        let a = semiMajorAxis * earthRadiusKm * 1000.0 // meters
        let cosI = cos(inclinationDeg * .pi / 180)
        let raan0 = raanDeg * .pi / 180
        let raanRate = -1.5 * j2 * n * (earthRadiusKm * 1000.0 / a)
            * (earthRadiusKm * 1000.0 / a) * cosI
        let secondsSinceEpoch = date.timeIntervalSince(j2000)
        let raan = raan0 + raanRate * secondsSinceEpoch

        // Position in orbital plane
        let xOrb = semiMajorAxis * cos(mRad)
        let yOrb = semiMajorAxis * sin(mRad)

        // Rotate by inclination (around x-axis of orbital plane)
        let incRad = inclinationDeg * .pi / 180
        let xInc = xOrb
        let yInc = yOrb * cos(incRad)
        let zInc = yOrb * sin(incRad)

        // Rotate by RAAN (around z-axis / polar axis)
        let x = xInc * cos(raan) - yInc * sin(raan)
        let y = xInc * sin(raan) + yInc * cos(raan)
        let z = zInc

        return (x, y, z)
    }

    /// Compute approximate ground position (latitude, longitude) at a given date.
    /// Accounts for Earth rotation to convert inertial frame to geographic coordinates.
    func groundPosition(at date: Date) -> (latitude: Double, longitude: Double) {
        let pos = position(at: date)
        let r = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
        guard r > 0.01 else { return (0, 0) }

        // Latitude from z component (polar axis)
        let lat = asin(pos.z / r) * 180 / .pi

        // Inertial longitude from x,y
        let inertialLon = atan2(pos.y, pos.x) * 180 / .pi

        // Subtract Earth rotation (GMST) to get geographic longitude
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                   timeZone: TimeZone(identifier: "UTC"),
                                   year: 2000, month: 1, day: 1,
                                   hour: 12, minute: 0, second: 0).date!
        let secondsSinceJ2000 = date.timeIntervalSince(j2000)
        let siderealDay = 86164.0905
        let earthRotation = (secondsSinceJ2000 / siderealDay * 360)
            .truncatingRemainder(dividingBy: 360)

        var geoLon = (inertialLon - earthRotation).truncatingRemainder(dividingBy: 360)
        if geoLon > 180 { geoLon -= 360 }
        if geoLon < -180 { geoLon += 360 }

        return (lat, geoLon)
    }

    /// Get a human-readable region name for a lat/lon position.
    static func regionName(latitude: Double, longitude: Double) -> String {
        // Approximate region lookup
        let lat = latitude
        let lon = longitude

        // Oceans first (most of Earth's surface)
        if lat < -60 { return "over the Southern Ocean near Antarctica" }
        if lat > 70 { return "over the Arctic" }

        // Atlantic Ocean: roughly -80 to 0 longitude
        if lon > -80 && lon < 0 && lat > -60 && lat < 70 {
            if lat > 30 { return "over the North Atlantic Ocean" }
            if lat > 0 { return "over the Atlantic Ocean" }
            return "over the South Atlantic Ocean"
        }

        // Pacific Ocean: roughly 100-180 and -180 to -80
        if (lon > 100 || lon < -80) && lat > -60 {
            if lat > 30 { return "over the North Pacific Ocean" }
            if lat > -10 { return "over the Pacific Ocean" }
            return "over the South Pacific Ocean"
        }

        // Indian Ocean: roughly 40-100 longitude, south of 25N
        if lon > 40 && lon < 100 && lat < 25 && lat > -60 {
            return "over the Indian Ocean"
        }

        // Land masses (approximate)
        if lat > 25 && lat < 72 && lon > -130 && lon < -50 { return "over North America" }
        if lat > -5 && lat <= 25 && lon > -120 && lon < -60 { return "over Central America" }
        if lat > -56 && lat <= -5 && lon > -82 && lon < -34 { return "over South America" }
        if lat > 35 && lat < 72 && lon >= 0 && lon < 60 { return "over Europe" }
        if lat > -37 && lat < 38 && lon > -20 && lon < 55 { return "over Africa" }
        if lat > 10 && lat < 55 && lon >= 60 && lon < 100 { return "over Central Asia" }
        if lat > 10 && lat < 55 && lon >= 100 && lon < 150 { return "over East Asia" }
        if lat > -10 && lat <= 10 && lon >= 95 && lon < 150 { return "over Southeast Asia" }
        if lat > -50 && lat < -10 && lon > 110 && lon < 155 { return "over Australia" }

        return "over the open ocean"
    }
}

// MARK: - Database Loader

enum SatelliteDatabase {
    private static var _cache: [OrbitalObject]?

    static var all: [OrbitalObject] {
        if let cache = _cache { return cache }
        guard let url = Bundle.main.url(forResource: "satellites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var sats = try? JSONDecoder().decode([OrbitalObject].self, from: data) else {
            return []
        }
        // Remove placeholder Starlink from JSON, replace with dense constellation
        sats.removeAll { $0.constellation == "Starlink" }
        sats.append(contentsOf: generateStarlinkConstellation())
        _cache = sats
        return _cache!
    }

    /// Generate ~300 Starlink satellites across multiple orbital shells.
    /// Real constellation: 6,000+ sats in 5 shells. We show representative density.
    private static func generateStarlinkConstellation() -> [OrbitalObject] {
        var sats: [OrbitalObject] = []

        // Shell 1: 550km, 53°, 72 planes — show 180 (36 planes × 5 sats)
        for plane in 0..<36 {
            let raan = Double(plane) * 10.0  // 360° / 36 planes
            for slot in 0..<5 {
                let ma = Double(slot) * 72.0  // 360° / 5 slots
                sats.append(OrbitalObject(
                    id: "sl1-p\(plane)-s\(slot)",
                    name: "Starlink",
                    constellation: "Starlink",
                    orbitType: "LEO",
                    altitudeKm: 550,
                    inclinationDeg: 53.0,
                    raanDeg: raan,
                    meanAnomalyDeg: ma + Double(plane) * 5.0, // phase offset
                    periodMinutes: 95.7,
                    icon: "⭐",
                    detail: "SpaceX broadband constellation",
                    launchYear: 2019
                ))
            }
        }

        // Shell 2: 540km, 53.2°, show 60 (12 planes × 5 sats)
        for plane in 0..<12 {
            let raan = Double(plane) * 30.0 + 5.0
            for slot in 0..<5 {
                let ma = Double(slot) * 72.0
                sats.append(OrbitalObject(
                    id: "sl2-p\(plane)-s\(slot)",
                    name: "Starlink",
                    constellation: "Starlink",
                    orbitType: "LEO",
                    altitudeKm: 540,
                    inclinationDeg: 53.2,
                    raanDeg: raan,
                    meanAnomalyDeg: ma + Double(plane) * 7.0,
                    periodMinutes: 95.6,
                    icon: "⭐",
                    detail: "SpaceX broadband constellation",
                    launchYear: 2019
                ))
            }
        }

        // Shell 3: 570km, 70°, show 36 (12 planes × 3 sats) — polar coverage
        for plane in 0..<12 {
            let raan = Double(plane) * 30.0 + 15.0
            for slot in 0..<3 {
                let ma = Double(slot) * 120.0
                sats.append(OrbitalObject(
                    id: "sl3-p\(plane)-s\(slot)",
                    name: "Starlink",
                    constellation: "Starlink",
                    orbitType: "LEO",
                    altitudeKm: 570,
                    inclinationDeg: 70.0,
                    raanDeg: raan,
                    meanAnomalyDeg: ma + Double(plane) * 11.0,
                    periodMinutes: 96.0,
                    icon: "⭐",
                    detail: "SpaceX broadband constellation",
                    launchYear: 2019
                ))
            }
        }

        return sats  // ~276 total
    }

    /// Return only satellites that had been launched by the given date.
    /// Pre-Sputnik (before Oct 4, 1957) returns empty array.
    static func active(at date: Date) -> [OrbitalObject] {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: date)
        return all.filter { sat in
            guard let ly = sat.launchYear else { return true }
            return year >= ly
        }
    }

    static var byOrbitType: [String: [OrbitalObject]] {
        Dictionary(grouping: all, by: { $0.orbitType })
    }

    static var constellations: [String: [OrbitalObject]] {
        Dictionary(grouping: all.filter { $0.constellation != nil }, by: { $0.constellation! })
    }

    static var individual: [OrbitalObject] {
        all.filter { $0.constellation == nil }
    }
}

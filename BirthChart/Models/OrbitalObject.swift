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
}

// MARK: - Database Loader

enum SatelliteDatabase {
    private static var _cache: [OrbitalObject]?

    static var all: [OrbitalObject] {
        if let cache = _cache { return cache }
        guard let url = Bundle.main.url(forResource: "satellites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sats = try? JSONDecoder().decode([OrbitalObject].self, from: data) else {
            return []
        }
        _cache = sats
        return _cache!
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

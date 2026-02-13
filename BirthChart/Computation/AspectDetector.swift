import Foundation

/// Detects the five major Ptolemaic aspects between pairs of celestial bodies.
enum AspectDetector {

    /// Compute the angular separation between two ecliptic longitudes (0–180°).
    static func angularSeparation(_ lon1: Double, _ lon2: Double) -> Double {
        let diff = abs(lon1 - lon2)
        return min(diff, 360 - diff)
    }

    /// Detect all aspects among a list of bodies.
    ///
    /// Tests all unique pairs against the five aspect types (conjunction, sextile,
    /// square, trine, opposition). Returns the first matching aspect per pair.
    /// Complexity: O(n² · k) where n = bodies, k = 5 aspect types.
    ///
    /// - Parameter bodies: Array of celestial bodies with ecliptic longitudes
    /// - Returns: Array of detected aspects
    static func detectAspects(bodies: [CelestialBody]) -> [Aspect] {
        var aspects: [Aspect] = []

        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let sep = angularSeparation(
                    bodies[i].eclipticLongitude,
                    bodies[j].eclipticLongitude
                )

                for aspectType in AspectType.allCases {
                    let orb = abs(sep - aspectType.nominalAngle)
                    if orb <= aspectType.maxOrb {
                        aspects.append(Aspect(
                            body1: bodies[i].name,
                            body2: bodies[j].name,
                            type: aspectType,
                            orb: orb
                        ))
                        break  // only one aspect per pair
                    }
                }
            }
        }

        return aspects
    }
}

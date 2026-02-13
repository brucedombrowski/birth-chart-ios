import Foundation

/// A celestial body's computed position in the birth chart.
struct CelestialBody: Identifiable {
    let id = UUID()
    let name: String
    let sign: ZodiacSign
    let degreeInSign: Double
    let eclipticLongitude: Double
    let isRetrograde: Bool

    var formattedDegree: String {
        let d = Int(degreeInSign)
        let m = Int((degreeInSign - Double(d)) * 60)
        return String(format: "%02d°%02d'", d, m)
    }

    var displayName: String {
        isRetrograde ? "\(name) ℞" : name
    }
}

/// Names of the ten primary bodies computed in the chart.
enum PlanetName: String, CaseIterable {
    case sun = "Sun"
    case moon = "Moon"
    case mercury = "Mercury"
    case venus = "Venus"
    case mars = "Mars"
    case jupiter = "Jupiter"
    case saturn = "Saturn"
    case uranus = "Uranus"
    case neptune = "Neptune"
    case pluto = "Pluto"
}

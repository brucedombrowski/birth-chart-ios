import Foundation

/// The complete computed birth chart result.
struct BirthChartResult {
    let planets: [CelestialBody]
    let ascendant: CelestialBody
    let midheaven: CelestialBody
    let northNode: CelestialBody
    let lilith: CelestialBody
    let moonPhase: MoonPhaseInfo
    let aspects: [Aspect]
    let elements: [Element: [String]]
    let modalities: [Modality: [String]]
    let dominantElement: Element
    let dominantModality: Modality
}

/// Moon phase information.
struct MoonPhaseInfo {
    let phaseName: String
    let illuminationPct: Double
    let emoji: String
}

/// Input parameters for chart computation.
struct BirthData {
    let name: String
    let date: Date
    let latitude: Double
    let longitude: Double
    let timeZoneOffset: Int  // hours from UTC

    /// Convert local date to UTC.
    var utcDate: Date {
        date.addingTimeInterval(Double(-timeZoneOffset) * 3600)
    }
}

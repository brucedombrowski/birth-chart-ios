import Foundation

/// A star with equatorial coordinates (J2000 epoch).
struct Star: Identifiable, Codable {
    let id: String
    let name: String
    let constellation: String
    let raDeg: Double       // Right Ascension in degrees (0-360)
    let decDeg: Double      // Declination in degrees (-90 to +90)
    let magnitude: Double   // Apparent magnitude (lower = brighter)
}

/// A constellation with stick-figure line segments connecting stars.
struct ConstellationPattern: Codable {
    let name: String
    let abbreviation: String
    let lines: [[String]]       // Pairs of star IDs to connect
    let labelStarId: String     // Star ID where to place the label
}

// MARK: - Data Loaders

enum StarDatabase {
    private static var _starCache: [Star]?
    private static var _patternCache: [ConstellationPattern]?

    static var allStars: [Star] {
        if let cache = _starCache { return cache }
        guard let url = Bundle.main.url(forResource: "stars", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stars = try? JSONDecoder().decode([Star].self, from: data) else {
            return []
        }
        _starCache = stars
        return stars
    }

    static var constellations: [ConstellationPattern] {
        if let cache = _patternCache { return cache }
        guard let url = Bundle.main.url(forResource: "constellation_lines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let patterns = try? JSONDecoder().decode([ConstellationPattern].self, from: data) else {
            return []
        }
        _patternCache = patterns
        return patterns
    }

    /// Look up a star by ID.
    static func star(byId id: String) -> Star? {
        allStars.first { $0.id == id }
    }
}

// MARK: - Precession of the Equinoxes

enum Precession {
    /// Full precession cycle: ~25,772 years.
    static let cycleDays: Double = 25_772 * 365.25

    /// Precession rate: degrees per year.
    static let degreesPerYear: Double = 360.0 / 25_772.0  // ~0.01396°/year

    /// Compute the precession angle (in radians) at a given date relative to J2000.
    /// This rotates the celestial sphere around the ecliptic pole.
    static func angle(at date: Date) -> Double {
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                   timeZone: TimeZone(identifier: "UTC"),
                                   year: 2000, month: 1, day: 1,
                                   hour: 12, minute: 0, second: 0).date!
        let years = date.timeIntervalSince(j2000) / (365.25 * 86400)
        return years * degreesPerYear * .pi / 180
    }

    /// The astrological age based on which constellation the vernal equinox falls in.
    /// Each age lasts ~2,148 years (25,772 / 12).
    static func astrologicalAge(at date: Date) -> String {
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                   timeZone: TimeZone(identifier: "UTC"),
                                   year: 2000, month: 1, day: 1,
                                   hour: 12, minute: 0, second: 0).date!
        let years = date.timeIntervalSince(j2000) / (365.25 * 86400)

        // At J2000, vernal equinox is at ~5° Pisces (sidereal).
        // The equinox precesses backward through the zodiac.
        // Approximate boundaries (years CE when equinox enters each sign):
        // Aries: ~2000 BCE - 100 BCE
        // Pisces: ~100 BCE - 2100 CE
        // Aquarius: ~2100 CE - 4200 CE
        let yearCE = 2000 + years
        switch yearCE {
        case ..<(-4000): return "Age of Gemini"
        case ..<(-2000): return "Age of Taurus"
        case ..<(-100):  return "Age of Aries"
        case ..<2100:    return "Age of Pisces"
        case ..<4200:    return "Age of Aquarius"
        case ..<6400:    return "Age of Capricorn"
        case ..<8600:    return "Age of Sagittarius"
        case ..<10800:   return "Age of Scorpio"
        case ..<13000:   return "Age of Libra"
        case ..<15200:   return "Age of Virgo"
        case ..<17400:   return "Age of Leo"
        case ..<19600:   return "Age of Cancer"
        default:         return "Age of Gemini"
        }
    }
}

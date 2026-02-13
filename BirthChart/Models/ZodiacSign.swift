import Foundation

/// The twelve signs of the tropical zodiac, each spanning 30° of ecliptic longitude.
enum ZodiacSign: Int, CaseIterable, Identifiable {
    case aries = 0, taurus, gemini, cancer
    case leo, virgo, libra, scorpio
    case sagittarius, capricorn, aquarius, pisces

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .aries: "Aries"
        case .taurus: "Taurus"
        case .gemini: "Gemini"
        case .cancer: "Cancer"
        case .leo: "Leo"
        case .virgo: "Virgo"
        case .libra: "Libra"
        case .scorpio: "Scorpio"
        case .sagittarius: "Sagittarius"
        case .capricorn: "Capricorn"
        case .aquarius: "Aquarius"
        case .pisces: "Pisces"
        }
    }

    var symbol: String {
        switch self {
        case .aries: "♈"
        case .taurus: "♉"
        case .gemini: "♊"
        case .cancer: "♋"
        case .leo: "♌"
        case .virgo: "♍"
        case .libra: "♎"
        case .scorpio: "♏"
        case .sagittarius: "♐"
        case .capricorn: "♑"
        case .aquarius: "♒"
        case .pisces: "♓"
        }
    }

    var element: Element {
        switch self {
        case .aries, .leo, .sagittarius: .fire
        case .taurus, .virgo, .capricorn: .earth
        case .gemini, .libra, .aquarius: .air
        case .cancer, .scorpio, .pisces: .water
        }
    }

    var modality: Modality {
        switch self {
        case .aries, .cancer, .libra, .capricorn: .cardinal
        case .taurus, .leo, .scorpio, .aquarius: .fixed
        case .gemini, .virgo, .sagittarius, .pisces: .mutable
        }
    }

    /// Convert ecliptic longitude (0–360°) to zodiac sign and degree within sign.
    static func from(longitude: Double) -> (sign: ZodiacSign, degree: Double) {
        let normalized = longitude.truncatingRemainder(dividingBy: 360)
        let lon = normalized < 0 ? normalized + 360 : normalized
        let idx = Int(lon / 30) % 12
        let deg = lon.truncatingRemainder(dividingBy: 30)
        return (ZodiacSign(rawValue: idx)!, deg)
    }
}

enum Element: String, CaseIterable {
    case fire = "Fire"
    case earth = "Earth"
    case air = "Air"
    case water = "Water"

    var emoji: String {
        switch self {
        case .fire: "🔥"
        case .earth: "🌍"
        case .air: "💨"
        case .water: "💧"
        }
    }
}

enum Modality: String, CaseIterable {
    case cardinal = "Cardinal"
    case fixed = "Fixed"
    case mutable = "Mutable"
}

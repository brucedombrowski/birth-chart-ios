import Foundation

/// A detected angular relationship between two celestial bodies.
struct Aspect: Identifiable {
    let id = UUID()
    let body1: String
    let body2: String
    let type: AspectType
    let orb: Double  // degrees from exact

    var formattedOrb: String {
        String(format: "%.1f°", orb)
    }
}

/// The five major Ptolemaic aspects.
enum AspectType: String, CaseIterable {
    case conjunction = "Conjunction"
    case sextile = "Sextile"
    case square = "Square"
    case trine = "Trine"
    case opposition = "Opposition"

    var nominalAngle: Double {
        switch self {
        case .conjunction: 0
        case .sextile: 60
        case .square: 90
        case .trine: 120
        case .opposition: 180
        }
    }

    var maxOrb: Double {
        switch self {
        case .conjunction: 8
        case .sextile: 6
        case .square: 7
        case .trine: 8
        case .opposition: 8
        }
    }

    var symbol: String {
        switch self {
        case .conjunction: "☌"
        case .sextile: "⚹"
        case .square: "□"
        case .trine: "△"
        case .opposition: "☍"
        }
    }
}

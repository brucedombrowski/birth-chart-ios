import Foundation

/// Moon phase determination from Sun and Moon ecliptic longitudes.
enum MoonPhaseCalculator {

    /// Compute the Moon's illumination percentage from Sun–Moon elongation.
    ///
    /// - Parameters:
    ///   - sunLon: Sun's ecliptic longitude in degrees
    ///   - moonLon: Moon's ecliptic longitude in degrees
    /// - Returns: Illumination percentage (0–100)
    static func illumination(sunLon: Double, moonLon: Double) -> Double {
        let elongation = abs(moonLon - sunLon)
        let psi = min(elongation, 360 - elongation) * .pi / 180
        return (1 - cos(psi)) / 2.0 * 100.0
    }

    /// Determine moon phase name and emoji from illumination and waxing/waning state.
    ///
    /// - Parameters:
    ///   - illuminationPct: Illumination percentage (0–100)
    ///   - isWaxing: Whether the Moon is waxing (illumination increasing)
    /// - Returns: MoonPhaseInfo with name, percentage, and emoji
    static func classify(illuminationPct: Double, isWaxing: Bool) -> MoonPhaseInfo {
        let name: String
        let emoji: String

        if illuminationPct < 1 {
            name = "New Moon"
            emoji = "🌑"
        } else if illuminationPct < 49 {
            name = isWaxing ? "Waxing Crescent" : "Waning Crescent"
            emoji = isWaxing ? "🌒" : "🌘"
        } else if illuminationPct < 51 {
            name = isWaxing ? "First Quarter" : "Last Quarter"
            emoji = isWaxing ? "🌓" : "🌗"
        } else if illuminationPct < 99 {
            name = isWaxing ? "Waxing Gibbous" : "Waning Gibbous"
            emoji = isWaxing ? "🌔" : "🌖"
        } else {
            name = "Full Moon"
            emoji = "🌕"
        }

        return MoonPhaseInfo(
            phaseName: name,
            illuminationPct: illuminationPct,
            emoji: emoji
        )
    }
}

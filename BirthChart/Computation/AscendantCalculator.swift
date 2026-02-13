import Foundation

/// Computes the Ascendant (Rising Sign) and Midheaven (MC) from observer parameters.
enum AscendantCalculator {

    /// Compute the Midheaven and Ascendant ecliptic longitudes.
    ///
    /// - Parameters:
    ///   - lst: Local Sidereal Time in radians
    ///   - latitudeDeg: Observer's geographic latitude in degrees
    /// - Returns: (ascendantDeg, midheavenDeg) — ecliptic longitudes in degrees (0–360)
    static func compute(lst: Double, latitudeDeg: Double) -> (ascendant: Double, midheaven: Double) {
        let latRad = latitudeDeg * .pi / 180
        let oblRad = CoordinateTransform.obliquityRad

        let cosLST = cos(lst)
        let sinLST = sin(lst)
        let cosObl = cos(oblRad)
        let sinObl = sin(oblRad)
        let tanLat = tan(latRad)

        // --- Midheaven (MC) ---
        // MC = atan2(sin(LST), cos(LST) · cos(ε))
        let mcRad = atan2(sinLST, cosLST * cosObl)
        let mcDeg = CoordinateTransform.normalizeDegrees(mcRad * 180 / .pi)

        // --- Ascendant ---
        // Raw formula: ASC = atan2(-cos(LST), sin(LST)·cos(ε) + tan(φ)·sin(ε))
        let ascRad = atan2(-cosLST, sinLST * cosObl + tanLat * sinObl)
        var ascDeg = CoordinateTransform.normalizeDegrees(ascRad * 180 / .pi)

        // CRITICAL DISAMBIGUATION:
        // atan2 can return the Descendant (180° off) instead of the Ascendant.
        // The Ascendant should be ~90° ahead of the MC in ecliptic longitude.
        // If it's ~270° ahead, we got the Descendant — add 180° to correct.
        let diffFromMC = CoordinateTransform.normalizeDegrees(ascDeg - mcDeg)
        if diffFromMC > 180 {
            ascDeg = CoordinateTransform.normalizeDegrees(ascDeg + 180)
        }

        return (ascDeg, mcDeg)
    }
}

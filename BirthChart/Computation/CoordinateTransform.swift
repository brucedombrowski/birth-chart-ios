import Foundation

/// Astronomical coordinate transformations.
enum CoordinateTransform {

    /// Mean obliquity of the ecliptic at J2000.0 in degrees.
    static let obliquityDeg: Double = 23.4393

    /// Mean obliquity in radians.
    static let obliquityRad: Double = 23.4393 * .pi / 180

    /// Convert equatorial coordinates (RA, Dec) to ecliptic longitude.
    ///
    /// - Parameters:
    ///   - ra: Right ascension in radians
    ///   - dec: Declination in radians
    /// - Returns: Ecliptic longitude in degrees (0–360)
    static func equatorialToEclipticLongitude(ra: Double, dec: Double) -> Double {
        let sinRA = sin(ra)
        let cosRA = cos(ra)
        let tanDec = tan(dec)
        let cosObl = cos(obliquityRad)
        let sinObl = sin(obliquityRad)

        let lambda = atan2(
            sinRA * cosObl + tanDec * sinObl,
            cosRA
        )

        let degrees = lambda * 180 / .pi
        return ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    /// Convert a Julian Date to Julian centuries from J2000.0.
    static func julianCenturies(fromJD jd: Double) -> Double {
        (jd - 2_451_545.0) / 36_525.0
    }

    /// Convert a Date to Julian Date.
    static func julianDate(from date: Date) -> Double {
        // Unix epoch (Jan 1, 1970 00:00 UTC) = JD 2440587.5
        let unixTime = date.timeIntervalSince1970
        return 2_440_587.5 + unixTime / 86_400.0
    }

    /// Compute Greenwich Mean Sidereal Time in radians for a given Julian Date.
    ///
    /// Uses the IAU formula from Meeus, Astronomical Algorithms.
    static func gmst(jd: Double) -> Double {
        let T = julianCenturies(fromJD: jd)
        // GMST at 0h UT in seconds
        var theta = 280.46061837
            + 360.98564736629 * (jd - 2_451_545.0)
            + 0.000387933 * T * T
            - T * T * T / 38_710_000.0

        theta = ((theta.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)

        return theta * .pi / 180  // convert to radians
    }

    /// Compute Local Sidereal Time in radians.
    ///
    /// - Parameters:
    ///   - jd: Julian Date
    ///   - longitudeDeg: Observer's geographic longitude in degrees (east positive)
    static func localSiderealTime(jd: Double, longitudeDeg: Double) -> Double {
        let gst = gmst(jd: jd)
        let lst = gst + longitudeDeg * .pi / 180
        return ((lst.truncatingRemainder(dividingBy: (2 * .pi))) + (2 * .pi))
            .truncatingRemainder(dividingBy: (2 * .pi))
    }

    /// Normalize an angle in degrees to [0, 360).
    static func normalizeDegrees(_ deg: Double) -> Double {
        ((deg.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    /// Normalize an angle in radians to [0, 2π).
    static func normalizeRadians(_ rad: Double) -> Double {
        ((rad.truncatingRemainder(dividingBy: (2 * .pi))) + (2 * .pi))
            .truncatingRemainder(dividingBy: (2 * .pi))
    }
}

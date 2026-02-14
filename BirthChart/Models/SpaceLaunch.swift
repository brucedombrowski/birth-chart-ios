import Foundation

/// A historic space launch event loaded from the bundled JSON database.
struct SpaceLaunch: Identifiable, Codable {
    let id: String              // unique key e.g. "apollo-11"
    let name: String
    let date: String            // ISO 8601 UTC e.g. "1969-07-16T13:32:00Z"
    let program: String
    let detail: String
    let icon: String
    let launchSite: LaunchSite
    let source: String          // citation URL or reference

    struct LaunchSite: Codable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    /// Parsed Date from ISO string.
    var parsedDate: Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: date) ?? {
            // Fallback for date-only strings
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "UTC")
            return df.date(from: String(date.prefix(10))) ?? Date.distantPast
        }()
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy HH:mm 'UTC'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: parsedDate)
    }

    /// BirthData at the launch site & time for ephemeris computation.
    var birthData: BirthData {
        BirthData(
            name: name,
            date: parsedDate,
            latitude: launchSite.latitude,
            longitude: launchSite.longitude,
            timeZoneOffset: 0  // dates stored as UTC
        )
    }
}

// MARK: - Database Loader

enum LaunchDatabase {
    private static var _cache: [SpaceLaunch]?

    static var all: [SpaceLaunch] {
        if let cache = _cache { return cache }
        guard let url = Bundle.main.url(forResource: "launches", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let launches = try? JSONDecoder().decode([SpaceLaunch].self, from: data) else {
            return []
        }
        _cache = launches.sorted { $0.parsedDate < $1.parsedDate }
        return _cache!
    }

    static let programs = [
        "Dawn of Space Age",
        "Mercury",
        "Vostok & Voskhod",
        "Gemini",
        "Apollo",
        "Planetary Probes",
        "Skylab & Salyut",
        "Military & Intelligence",
        "Space Shuttle",
        "Planetary Exploration",
        "Space Stations",
        "Modern Era",
        "Artemis & Beyond",
    ]

    static var grouped: [(program: String, launches: [SpaceLaunch])] {
        programs.compactMap { prog in
            let launches = all.filter { $0.program == prog }
            return launches.isEmpty ? nil : (prog, launches)
        }
    }
}

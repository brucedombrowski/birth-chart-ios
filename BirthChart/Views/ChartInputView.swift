import SwiftUI

/// Birth data entry form with celestial styling.
struct ChartInputView: View {
    @State private var name: String = ""
    @State private var birthDate = Date()
    @State private var birthTime = Date()
    @State private var city: String = ""
    @State private var selectedState: String = "CA"
    @State private var selectedTimezone: String = "PST"
    @State private var isComputing = false

    let onComplete: (BirthChartResult, String, BirthData) -> Void

    private let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
    ]

    private let timezones: [(String, Int)] = [
        ("EST (UTC-5)", -5),
        ("CST (UTC-6)", -6),
        ("MST (UTC-7)", -7),
        ("PST (UTC-8)", -8),
        ("AKST (UTC-9)", -9),
        ("HST (UTC-10)", -10),
    ]

    // Built-in city coordinates (subset — same as web app)
    private let cityCoords: [String: [String: (Double, Double)]] = [
        "CA": ["los angeles": (34.0522, -118.2437), "san francisco": (37.7749, -122.4194),
               "san diego": (32.7157, -117.1611), "sacramento": (38.5816, -121.4944),
               "san jose": (37.3382, -121.8863), "fresno": (36.7378, -119.7871),
               "long beach": (33.7701, -118.1937), "oakland": (37.8044, -122.2712),
               "bakersfield": (35.3733, -119.0187), "anaheim": (33.8366, -117.9143),
               "irvine": (33.6846, -117.8265), "riverside": (33.9806, -117.3755)],
        "TX": ["houston": (29.7604, -95.3698), "dallas": (32.7767, -96.7970),
               "austin": (30.2672, -97.7431), "san antonio": (29.4241, -98.4936),
               "fort worth": (32.7555, -97.3308), "el paso": (31.7619, -106.4850)],
        "NY": ["new york": (40.7128, -74.0060), "buffalo": (42.8864, -78.8784),
               "albany": (42.6526, -73.7562)],
        "FL": ["miami": (25.7617, -80.1918), "orlando": (28.5383, -81.3792),
               "tampa": (27.9506, -82.4572), "jacksonville": (30.3322, -81.6557)],
        "IL": ["chicago": (41.8781, -87.6298), "springfield": (39.7817, -89.6501)],
        "PA": ["philadelphia": (39.9526, -75.1652), "pittsburgh": (40.4406, -79.9959)],
        "AZ": ["phoenix": (33.4484, -112.0740), "tucson": (32.2226, -110.9747)],
        "GA": ["atlanta": (33.7490, -84.3880), "savannah": (32.0809, -81.0912)],
        "WA": ["seattle": (47.6062, -122.3321), "olympia": (47.0379, -122.9007)],
        "CO": ["denver": (39.7392, -104.9903), "colorado springs": (38.8339, -104.8214)],
        "MA": ["boston": (42.3601, -71.0589)],
        "MI": ["detroit": (42.3314, -83.0458)],
        "TN": ["nashville": (36.1627, -86.7816), "memphis": (35.1495, -90.0490)],
        "OR": ["portland": (45.5152, -122.6784), "salem": (44.9429, -123.0351)],
        "NV": ["las vegas": (36.1699, -115.1398), "reno": (39.5296, -119.8138)],
        "MO": ["kansas city": (39.0997, -94.5786), "st louis": (38.6270, -90.1994)],
        "MN": ["minneapolis": (44.9778, -93.2650)],
        "OH": ["columbus": (39.9612, -82.9988), "cleveland": (41.4993, -81.6944)],
        "NC": ["charlotte": (35.2271, -80.8431), "raleigh": (35.7796, -78.6382)],
        "LA": ["new orleans": (29.9511, -90.0715), "baton rouge": (30.4515, -91.1871)],
        "IN": ["indianapolis": (39.7684, -86.1581)],
        "HI": ["honolulu": (21.3069, -157.8583)],
        "AK": ["anchorage": (61.2181, -149.9003)],
        "DC": ["washington": (38.9072, -77.0369)],
        "MD": ["baltimore": (39.2904, -76.6122)],
        "WI": ["milwaukee": (43.0389, -87.9065), "madison": (43.0731, -89.4012)],
        "UT": ["salt lake city": (40.7608, -111.8910)],
        "VA": ["richmond": (37.5407, -77.4360)],
        "ID": ["boise": (43.6150, -116.2023)],
        "NE": ["omaha": (41.2565, -95.9345)],
        "OK": ["oklahoma city": (35.4676, -97.5164), "tulsa": (36.1540, -95.9928)],
        "KY": ["louisville": (38.2527, -85.7585)],
        "NM": ["albuquerque": (35.0844, -106.6504), "santa fe": (35.6870, -105.9378)],
        "SC": ["charleston": (32.7765, -79.9311), "columbia": (34.0007, -81.0348)],
        "AL": ["birmingham": (33.5207, -86.8025)],
        "AR": ["little rock": (34.7465, -92.2896)],
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Birth Chart Generator")
                        .font(.title.bold())
                        .foregroundColor(Color(red: 0.831, green: 0.659, blue: 0.263))

                    Text("Astronomical positions via Keplerian ephemeris")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Label("All data processed locally", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.941, green: 0.843, blue: 0.549))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.831, green: 0.659, blue: 0.263).opacity(0.15))
                        )
                }
                .padding(.top, 20)

                // Form
                VStack(spacing: 16) {
                    formField(label: "Name (optional)") {
                        TextField("e.g. Bruce", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        formField(label: "Birth Date") {
                            DatePicker("", selection: $birthDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        formField(label: "Birth Time") {
                            DatePicker("", selection: $birthTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }

                    HStack(spacing: 12) {
                        formField(label: "City") {
                            TextField("e.g. Los Angeles", text: $city)
                                .textFieldStyle(.roundedBorder)
                        }
                        formField(label: "State") {
                            Picker("", selection: $selectedState) {
                                ForEach(states, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    formField(label: "Timezone at Birth") {
                        Picker("", selection: $selectedTimezone) {
                            ForEach(timezones, id: \.0) { tz in
                                Text(tz.0).tag(tz.0)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.831, green: 0.659, blue: 0.263).opacity(0.2))
                        )
                )

                // Submit
                Button(action: generateChart) {
                    HStack {
                        if isComputing {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(isComputing ? "Computing..." : "Generate Birth Chart")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.831, green: 0.659, blue: 0.263),
                                Color(red: 0.722, green: 0.569, blue: 0.180),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(city.isEmpty || isComputing)
            }
            .padding()
        }
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color(red: 0.831, green: 0.659, blue: 0.263))
                .bold()
            content()
        }
    }

    private func generateChart() {
        // Resolve coordinates
        let cityKey = city.lowercased().trimmingCharacters(in: .whitespaces)
        guard let coords = cityCoords[selectedState]?[cityKey] else {
            // Default to state capital or show error
            // For now, use a rough center-of-US fallback
            return
        }

        let tzOffset = timezones.first(where: { $0.0 == selectedTimezone })?.1 ?? -5

        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: birthTime)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.timeZone = TimeZone(secondsFromGMT: tzOffset * 3600)

        guard let fullDate = calendar.date(from: combined) else { return }

        isComputing = true

        let birthData = BirthData(
            name: name.isEmpty ? "Your" : name,
            date: fullDate,
            latitude: coords.0,
            longitude: coords.1,
            timeZoneOffset: tzOffset
        )

        // Compute on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let result = EphemerisEngine.computeChart(birthData: birthData)
            DispatchQueue.main.async {
                isComputing = false
                onComplete(result, birthData.name, birthData)
            }
        }
    }
}

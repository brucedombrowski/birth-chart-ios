import SwiftUI

/// Displays the computed birth chart with all sections.
struct ChartResultView: View {
    let chart: BirthChartResult
    let birthData: BirthData
    let name: String
    let onReset: () -> Void

    private let gold = Color(red: 0.831, green: 0.659, blue: 0.263)
    private let goldLight = Color(red: 0.941, green: 0.843, blue: 0.549)
    private let cream = Color(red: 0.961, green: 0.941, blue: 0.910)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("\(name)'s Night Sky")
                        .font(.title.bold())
                        .foregroundColor(gold)
                }
                .padding(.top)

                // Highlights: Sun, Moon, Rising
                highlightsSection

                // Planet table
                planetTableSection

                // Moon phase
                moonPhaseSection

                // Elements & Modalities
                distributionSection

                // Aspects
                aspectsSection

                // 3D view link
                NavigationLink {
                    SolarSystemView(chart: chart, birthData: birthData)
                } label: {
                    Label("View 3D Solar System", systemImage: "globe")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(gold.opacity(0.2))
                        .foregroundColor(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Generate another
                Button(action: onReset) {
                    Text("Generate Another Chart")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [gold, Color(red: 0.722, green: 0.569, blue: 0.180)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Positions computed via Keplerian ephemeris.\nTropical zodiac. Geocentric ecliptic longitudes.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .padding()
        }
    }

    // MARK: - Highlights

    private var highlightsSection: some View {
        HStack(spacing: 8) {
            if let sun = chart.planets.first(where: { $0.name == "Sun" }) {
                highlightCard(icon: "☀️", title: "Sun in \(sun.sign.symbol) \(sun.sign.name)", detail: sun.formattedDegree)
            }
            if let moon = chart.planets.first(where: { $0.name == "Moon" }) {
                highlightCard(icon: chart.moonPhase.emoji, title: "Moon in \(moon.sign.symbol) \(moon.sign.name)", detail: moon.formattedDegree)
            }
            highlightCard(icon: "⬆️", title: "Rising: \(chart.ascendant.sign.symbol) \(chart.ascendant.sign.name)", detail: chart.ascendant.formattedDegree)
        }
    }

    private func highlightCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.title)
            Text(title).font(.caption2).bold().foregroundColor(goldLight)
            Text(detail).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(gold.opacity(0.2)))
        )
    }

    // MARK: - Planet Table

    private var planetTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planetary Positions")
                .font(.headline)
                .foregroundColor(gold)

            ForEach(Array(chart.planets.enumerated()), id: \.offset) { idx, body in
                HStack {
                    Text(body.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(cream)
                        .frame(width: 90, alignment: .leading)

                    Text("\(body.sign.symbol) \(body.sign.name)")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(body.formattedDegree)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(idx % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
            }

            Divider().overlay(gold.opacity(0.3))

            // ASC, MC, Node, Lilith
            ForEach([chart.ascendant, chart.midheaven, chart.northNode, chart.lilith], id: \.name) { body in
                HStack {
                    Text(body.name)
                        .font(.subheadline.bold().italic())
                        .foregroundColor(goldLight)
                        .frame(width: 90, alignment: .leading)

                    Text("\(body.sign.symbol) \(body.sign.name)")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(body.formattedDegree)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Moon Phase

    private var moonPhaseSection: some View {
        HStack(spacing: 16) {
            Text(chart.moonPhase.emoji).font(.system(size: 48))
            VStack(alignment: .leading) {
                Text(chart.moonPhase.phaseName).font(.headline).foregroundColor(cream)
                Text(String(format: "%.1f%% illumination", chart.moonPhase.illuminationPct))
                    .font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(gold.opacity(0.2)))
        )
    }

    // MARK: - Elements & Modalities

    private var distributionSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Elements").font(.headline).foregroundColor(gold)
                Text("Dominant: \(chart.dominantElement.rawValue)")
                    .font(.caption).italic().foregroundColor(goldLight)
                ForEach(Element.allCases, id: \.self) { el in
                    let bodies = chart.elements[el] ?? []
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(el.emoji) \(el.rawValue)")
                            .font(.caption.bold())
                            .foregroundColor(elementColor(el))
                        Text("\(bodies.joined(separator: ", ")) (\(bodies.count))")
                            .font(.caption2).foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))

            VStack(alignment: .leading, spacing: 8) {
                Text("Modalities").font(.headline).foregroundColor(gold)
                Text("Dominant: \(chart.dominantModality.rawValue)")
                    .font(.caption).italic().foregroundColor(goldLight)
                ForEach(Modality.allCases, id: \.self) { mod in
                    let bodies = chart.modalities[mod] ?? []
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mod.rawValue)
                            .font(.caption.bold())
                        Text("\(bodies.joined(separator: ", ")) (\(bodies.count))")
                            .font(.caption2).foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }

    private func elementColor(_ el: Element) -> Color {
        switch el {
        case .fire: .red
        case .earth: .green
        case .air: .cyan
        case .water: .blue
        }
    }

    // MARK: - Aspects

    private var aspectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planetary Aspects").font(.headline).foregroundColor(gold)

            ForEach(chart.aspects) { aspect in
                HStack {
                    Text(aspect.body1)
                        .font(.caption.bold())
                        .frame(width: 70, alignment: .trailing)
                    Text("\(aspect.type.symbol) \(aspect.type.rawValue)")
                        .font(.caption)
                        .foregroundColor(goldLight)
                        .frame(width: 100)
                    Text(aspect.body2)
                        .font(.caption.bold())
                        .frame(width: 70, alignment: .leading)
                    Spacer()
                    Text(aspect.formattedOrb)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
    }
}

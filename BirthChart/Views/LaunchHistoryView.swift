import SwiftUI

/// Browse historic space launches and view the solar system at each launch date.
struct LaunchHistoryView: View {
    @State private var searchText = ""
    @State private var selectedProgram: String?

    private let gold = Color(red: 0.831, green: 0.659, blue: 0.263)
    private let goldLight = Color(red: 0.941, green: 0.843, blue: 0.549)

    private var filteredGroups: [(program: String, launches: [SpaceLaunch])] {
        let groups = LaunchDatabase.grouped
        if searchText.isEmpty && selectedProgram == nil { return groups }
        return groups.compactMap { group in
            if let sel = selectedProgram, group.program != sel { return nil }
            let launches = searchText.isEmpty ? group.launches : group.launches.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.detail.localizedCaseInsensitiveContains(searchText) ||
                $0.launchSite.name.localizedCaseInsensitiveContains(searchText)
            }
            return launches.isEmpty ? nil : (group.program, launches)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Launch History")
                        .font(.title.bold())
                        .foregroundColor(gold)
                    Text("\(LaunchDatabase.all.count) launches · Sputnik to Artemis")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search launches...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Program filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        programChip(nil, label: "All")
                        ForEach(LaunchDatabase.programs, id: \.self) { prog in
                            programChip(prog, label: prog)
                        }
                    }
                }

                // Launch list
                ForEach(filteredGroups, id: \.program) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.program)
                            .font(.headline)
                            .foregroundColor(gold)
                            .padding(.top, 4)

                        ForEach(group.launches) { launch in
                            NavigationLink {
                                SolarSystemView(
                                    chart: EphemerisEngine.computeChart(birthData: launch.birthData),
                                    birthData: launch.birthData
                                )
                                .navigationTitle(launch.name)
                            } label: {
                                launchRow(launch)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("")
    }

    private func programChip(_ program: String?, label: String) -> some View {
        let isSelected = selectedProgram == program
        return Button {
            withAnimation { selectedProgram = program }
        } label: {
            Text(label)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? gold.opacity(0.3) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? gold : .gray)
                .clipShape(Capsule())
        }
    }

    private func launchRow(_ launch: SpaceLaunch) -> some View {
        HStack(spacing: 12) {
            Text(launch.icon)
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(launch.name)
                    .font(.subheadline.bold())
                    .foregroundColor(goldLight)
                    .lineLimit(1)

                Text(launch.detail)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(launch.formattedDate)
                    Text("·")
                    Text(launch.launchSite.name)
                }
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(gold.opacity(0.5))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
}

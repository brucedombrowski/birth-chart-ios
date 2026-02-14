import SwiftUI

/// Root tab view — Birth Chart generator or Launch History browser.
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BirthChartTab()
                .tabItem {
                    Label("Birth Chart", systemImage: "sparkles")
                }
                .tag(0)

            NavigationStack {
                ZStack {
                    Color(red: 0.043, green: 0.055, blue: 0.176)
                        .ignoresSafeArea()
                    LaunchHistoryView()
                }
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem {
                Label("Launches", systemImage: "airplane.departure")
            }
            .tag(1)
        }
        .tint(Color(red: 0.831, green: 0.659, blue: 0.263))
    }
}

/// Birth chart input / result flow.
private struct BirthChartTab: View {
    @State private var chartResult: BirthChartResult?
    @State private var chartName: String = ""
    @State private var birthData: BirthData?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.043, green: 0.055, blue: 0.176)
                    .ignoresSafeArea()

                if let chart = chartResult, let data = birthData {
                    ChartResultView(
                        chart: chart,
                        birthData: data,
                        name: chartName,
                        onReset: { chartResult = nil; birthData = nil }
                    )
                } else {
                    ChartInputView { result, name, data in
                        chartName = name
                        chartResult = result
                        birthData = data
                    }
                }
            }
            .navigationTitle("")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

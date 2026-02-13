import SwiftUI

/// Root navigation view — form input or chart results.
struct ContentView: View {
    @State private var chartResult: BirthChartResult?
    @State private var chartName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Celestial background
                Color(red: 0.043, green: 0.055, blue: 0.176)
                    .ignoresSafeArea()

                if let chart = chartResult {
                    ChartResultView(
                        chart: chart,
                        name: chartName,
                        onReset: { chartResult = nil }
                    )
                } else {
                    ChartInputView { result, name in
                        chartName = name
                        chartResult = result
                    }
                }
            }
            .navigationTitle("")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

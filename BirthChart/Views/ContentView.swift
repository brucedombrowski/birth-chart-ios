import SwiftUI

/// Root navigation view — form input or chart results.
struct ContentView: View {
    @State private var chartResult: BirthChartResult?
    @State private var chartName: String = ""
    @State private var birthData: BirthData?

    var body: some View {
        NavigationStack {
            ZStack {
                // Celestial background
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

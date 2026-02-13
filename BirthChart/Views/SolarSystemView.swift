import SwiftUI
import SceneKit

/// Full-screen 3D solar system view showing planet positions at birth.
struct SolarSystemView: View {
    let chart: BirthChartResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            SceneView(
                scene: SolarSystemScene.build(from: chart),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            // Overlay info
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Pinch to zoom")
                        Text("Drag to orbit")
                        Text("Two-finger drag to pan")
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(8)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Solar System")
        .navigationBarTitleDisplayMode(.inline)
    }
}

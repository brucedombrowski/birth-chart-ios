import SwiftUI
import SceneKit

/// Geocentric 3D view: Earth at center with LEO/MEO/GEO satellites orbiting.
/// Supports DualSense controller for camera and time scrubbing.
struct EarthOrbitView: View {
    let initialDate: Date
    let chart: BirthChartResult?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = GameControllerManager()
    @State private var timeOffsetDays: Double = 0
    @State private var showLabels = true
    @State private var currentDateString = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EarthOrbitSceneView(
                initialDate: initialDate,
                chart: chart,
                controller: controller,
                timeOffsetDays: $timeOffsetDays,
                showLabels: $showLabels,
                currentDateString: $currentDateString
            )
            .ignoresSafeArea()

            // Overlay
            VStack {
                HStack {
                    // Time display
                    if timeOffsetDays != 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentDateString)
                                .font(.caption)
                                .fontWeight(.medium)
                            let days = Int(timeOffsetDays)
                            Text(days >= 0 ? "+\(days) days" : "\(days) days")
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    // Satellite count
                    VStack(alignment: .trailing, spacing: 2) {
                        let sats = SatelliteDatabase.all
                        Text("\(sats.count) satellites")
                            .font(.caption2).fontWeight(.medium)
                        let leo = sats.filter { $0.orbitType == "LEO" }.count
                        let meo = sats.filter { $0.orbitType == "MEO" }.count
                        let geo = sats.filter { $0.orbitType == "GEO" }.count
                        Text("LEO: \(leo) · MEO: \(meo) · GEO: \(geo)")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(8)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()

                // Legend
                HStack(spacing: 16) {
                    legendDot(color: .yellow, label: "Station")
                    legendDot(color: .white, label: "Starlink")
                    legendDot(color: .green, label: "LEO")
                    legendDot(color: .orange, label: "MEO/GPS")
                    legendDot(color: .purple, label: "GEO")
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .padding(8)
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .navigationTitle("Earth Orbit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}

// MARK: - UIViewRepresentable

struct EarthOrbitSceneView: UIViewRepresentable {
    let initialDate: Date
    let chart: BirthChartResult?
    let controller: GameControllerManager
    @Binding var timeOffsetDays: Double
    @Binding var showLabels: Bool
    @Binding var currentDateString: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = GeocentricScene.build(date: initialDate, chart: chart)
        scnView.scene = scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.delegate = context.coordinator
        scnView.isPlaying = true

        context.coordinator.scnView = scnView
        context.coordinator.scene = scene
        context.coordinator.cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil })

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: EarthOrbitSceneView
        weak var scnView: SCNView?
        var scene: SCNScene?
        var cameraNode: SCNNode?

        private var orbitAngleH: Float = 0
        private var orbitAngleV: Float = 0.5
        private var orbitDistance: Float = 22
        private var lastTime: TimeInterval = 0
        private var lastRecompute: TimeInterval = 0
        private let deadzone: Float = 0.1

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        init(_ parent: EarthOrbitSceneView) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt: Float = lastTime == 0 ? 1.0 / 60.0 : Float(min(time - lastTime, 0.05))
            lastTime = time

            let lx = parent.controller.leftStickX
            let ly = parent.controller.leftStickY
            let ry = parent.controller.rightStickY
            let l2 = parent.controller.leftTrigger
            let r2 = parent.controller.rightTrigger
            let crossJust = parent.controller.crossJustPressed
            let triJust = parent.controller.triangleJustPressed

            guard parent.controller.isConnected else {
                // Auto-rotate satellites even without controller (every ~2 seconds for smooth orbits)
                if abs(time - lastRecompute) > 2.0 && parent.timeOffsetDays == 0 {
                    lastRecompute = time
                    DispatchQueue.main.async { [weak self] in
                        guard let self, let scene = self.scene else { return }
                        let now = Date()
                        GeocentricScene.updatePositions(in: scene, date: now, chart: self.parent.chart)
                    }
                }
                return
            }

            if let sv = scnView, sv.allowsCameraControl {
                sv.allowsCameraControl = false
            }

            // Left stick: orbit (full spherical)
            if abs(lx) > deadzone { orbitAngleH += lx * dt * 2.0 }
            if abs(ly) > deadzone {
                orbitAngleV -= ly * dt * 1.5
                orbitAngleV = max(-Float.pi / 2 + 0.05, min(Float.pi / 2 - 0.05, orbitAngleV))
            }

            // Right stick: zoom
            if abs(ry) > deadzone {
                orbitDistance -= ry * dt * 20.0
                orbitDistance = max(5, min(50, orbitDistance))
            }

            // Camera
            if let cam = cameraNode {
                let x = orbitDistance * cos(orbitAngleV) * sin(orbitAngleH)
                let y = orbitDistance * sin(orbitAngleV)
                let z = orbitDistance * cos(orbitAngleV) * cos(orbitAngleH)
                cam.position = SCNVector3(x, y, z)
                cam.look(at: SCNVector3(0, 0, 0))
            }

            // Triggers: time scrub (faster for satellites — 1 day/sec at full trigger)
            let timeSpeed: Double = 1.0  // days per second at full trigger
            let forward = Double(r2 * r2) * timeSpeed * Double(dt)
            let backward = Double(l2 * l2) * timeSpeed * Double(dt)
            let timeDelta = forward - backward

            if abs(timeDelta) > 0.00001 {
                let newOffset = parent.timeOffsetDays + timeDelta

                if abs(time - lastRecompute) > 0.05 {
                    lastRecompute = time
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.parent.timeOffsetDays = newOffset
                        self.recomputePositions(offsetDays: newOffset)
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.timeOffsetDays = newOffset
                    }
                }
            }

            if crossJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.timeOffsetDays = 0
                    self.parent.controller.crossJustPressed = false
                    self.resetPositions()
                }
            }

            if triJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.showLabels.toggle()
                    self.parent.controller.triangleJustPressed = false
                    self.toggleLabels(visible: self.parent.showLabels)
                }
            }
        }

        private func recomputePositions(offsetDays: Double) {
            let newDate = parent.initialDate.addingTimeInterval(offsetDays * 86400)
            parent.currentDateString = dateFormatter.string(from: newDate)

            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }
                // Recompute chart for moon position
                let birthData = BirthData(name: "Now", date: newDate,
                                          latitude: 0, longitude: 0, timeZoneOffset: 0)
                let newChart = EphemerisEngine.computeChart(birthData: birthData)
                DispatchQueue.main.async {
                    guard let scene = self.scene else { return }
                    GeocentricScene.updatePositions(in: scene, date: newDate, chart: newChart)
                }
            }
        }

        private func resetPositions() {
            guard let scene else { return }
            parent.currentDateString = ""
            GeocentricScene.updatePositions(in: scene, date: parent.initialDate, chart: parent.chart)
        }

        private func toggleLabels(visible: Bool) {
            guard let scene else { return }
            scene.rootNode.enumerateChildNodes { node, _ in
                if node.geometry is SCNText {
                    node.isHidden = !visible
                }
            }
        }
    }
}

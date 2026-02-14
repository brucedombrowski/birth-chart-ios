import SwiftUI
import SceneKit

/// Full-screen 3D solar system view with DualSense controller support.
/// Left stick: orbit camera. Right stick Y: zoom. R2/L2: time forward/rewind.
/// Cross: reset to birth time. Triangle: toggle labels.
struct SolarSystemView: View {
    let chart: BirthChartResult
    let birthData: BirthData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = GameControllerManager()
    @State private var timeOffsetDays: Double = 0
    @State private var showLabels = true
    @State private var currentDateString = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            SolarSystemSceneView(
                chart: chart,
                birthData: birthData,
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

                    if controller.connected {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("🎮 DualSense")
                                .font(.caption2)
                                .fontWeight(.medium)
                            Text("L stick: orbit")
                            Text("R stick: zoom")
                            Text("R2/L2: time")
                            Text("✕ reset  △ labels")
                        }
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(8)
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
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
                }
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Solar System")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UIViewRepresentable wrapping SCNView with game loop

struct SolarSystemSceneView: UIViewRepresentable {
    let chart: BirthChartResult
    let birthData: BirthData
    let controller: GameControllerManager
    @Binding var timeOffsetDays: Double
    @Binding var showLabels: Bool
    @Binding var currentDateString: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SolarSystemScene.build(from: chart)
        scnView.scene = scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.delegate = context.coordinator
        scnView.isPlaying = true  // keeps the render loop alive

        context.coordinator.scnView = scnView
        context.coordinator.scene = scene
        context.coordinator.cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil })

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: SolarSystemSceneView
        weak var scnView: SCNView?
        var scene: SCNScene?
        var cameraNode: SCNNode?

        // Camera orbit state
        private var orbitAngleH: Float = 0
        private var orbitAngleV: Float = 0.65
        private var orbitDistance: Float = 38
        private var lastTime: TimeInterval = 0
        private var lastRecompute: TimeInterval = 0

        // Deadzone for sticks
        private let deadzone: Float = 0.1

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        init(_ parent: SolarSystemSceneView) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt: Float = lastTime == 0 ? 1.0 / 60.0 : Float(min(time - lastTime, 0.05))
            lastTime = time

            // Read controller state (these are just floats, safe to read from render thread)
            let lx = parent.controller.leftStickX
            let ly = parent.controller.leftStickY
            let ry = parent.controller.rightStickY
            let l2 = parent.controller.leftTrigger
            let r2 = parent.controller.rightTrigger
            let crossJust = parent.controller.crossJustPressed
            let triJust = parent.controller.triangleJustPressed

            guard parent.controller.isConnected else { return }

            // Disable SceneKit's default camera control when controller is active
            if let sv = scnView, sv.allowsCameraControl {
                sv.allowsCameraControl = false
            }

            // Left stick: orbit
            if abs(lx) > deadzone {
                orbitAngleH += lx * dt * 2.0
            }
            if abs(ly) > deadzone {
                orbitAngleV -= ly * dt * 1.5
                orbitAngleV = max(0.05, min(Float.pi / 2.0 - 0.05, orbitAngleV))
            }

            // Right stick Y: zoom
            if abs(ry) > deadzone {
                orbitDistance -= ry * dt * 25.0
                orbitDistance = max(5, min(80, orbitDistance))
            }

            // Update camera position
            if let cam = cameraNode {
                let x = orbitDistance * cos(orbitAngleV) * sin(orbitAngleH)
                let y = orbitDistance * sin(orbitAngleV)
                let z = orbitDistance * cos(orbitAngleV) * cos(orbitAngleH)
                cam.position = SCNVector3(x, y, z)
                cam.look(at: SCNVector3(0, 0, 0))
            }

            // Triggers: time scrub
            // Full trigger = 30 days per second. Exponential feel.
            let timeSpeed: Double = 30.0
            let forward = Double(r2 * r2) * timeSpeed * Double(dt)
            let backward = Double(l2 * l2) * timeSpeed * Double(dt)
            let timeDelta = forward - backward

            if abs(timeDelta) > 0.0001 {
                let newOffset = parent.timeOffsetDays + timeDelta

                // Recompute positions every ~100ms
                if abs(time - lastRecompute) > 0.1 {
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

            // Cross: reset time
            if crossJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.timeOffsetDays = 0
                    self.parent.controller.crossJustPressed = false
                    self.resetPositions()
                }
            }

            // Triangle: toggle labels
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
            let newDate = parent.birthData.date.addingTimeInterval(offsetDays * 86400)
            let newBirthData = BirthData(
                name: parent.birthData.name,
                date: newDate,
                latitude: parent.birthData.latitude,
                longitude: parent.birthData.longitude,
                timeZoneOffset: parent.birthData.timeZoneOffset
            )

            parent.currentDateString = dateFormatter.string(from: newDate)

            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                let newChart = EphemerisEngine.computeChart(birthData: newBirthData)
                DispatchQueue.main.async {
                    guard let self, let scene = self.scene else { return }
                    SolarSystemScene.updatePositions(in: scene, from: newChart)
                }
            }
        }

        private func resetPositions() {
            guard let scene else { return }
            parent.currentDateString = ""
            SolarSystemScene.updatePositions(in: scene, from: parent.chart)
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

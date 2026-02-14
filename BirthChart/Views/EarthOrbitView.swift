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
    @State private var speedLabel = ""
    @State private var activeSatCount = 0
    @State private var isISSCamera = false
    @State private var astroAge = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EarthOrbitSceneView(
                initialDate: initialDate,
                chart: chart,
                controller: controller,
                timeOffsetDays: $timeOffsetDays,
                showLabels: $showLabels,
                currentDateString: $currentDateString,
                speedLabel: $speedLabel,
                activeSatCount: $activeSatCount,
                isISSCamera: $isISSCamera,
                astroAge: $astroAge
            )
            .ignoresSafeArea()

            // Overlay
            VStack {
                HStack(alignment: .top) {
                    // Time display
                    VStack(alignment: .leading, spacing: 2) {
                        if timeOffsetDays != 0 {
                            Text(currentDateString)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(formatTimeOffset(timeOffsetDays))
                                .font(.caption2)
                        }
                        if !speedLabel.isEmpty {
                            Text(speedLabel)
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                        if !astroAge.isEmpty {
                            Text(astroAge)
                                .font(.caption2)
                                .foregroundColor(.yellow.opacity(0.7))
                        }
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(timeOffsetDays != 0 || !speedLabel.isEmpty || !astroAge.isEmpty ? 8 : 0)
                    .background(.ultraThinMaterial.opacity(timeOffsetDays != 0 || !speedLabel.isEmpty || !astroAge.isEmpty ? 0.3 : 0))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    // Satellite count + ISS camera indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        if isISSCamera {
                            Text("ISS Cupola View")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                        let count = activeSatCount > 0 ? activeSatCount : SatelliteDatabase.all.count
                        Text("\(count) satellites")
                            .font(.caption2).fontWeight(.medium)
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

    private func formatTimeOffset(_ days: Double) -> String {
        let absDays = abs(days)
        let sign = days >= 0 ? "+" : "-"
        if absDays < 1 {
            let hours = Int(absDays * 24)
            return "\(sign)\(hours) hours"
        } else if absDays < 365 {
            return "\(sign)\(Int(absDays)) days"
        } else {
            let years = Int(absDays / 365.25)
            let remaining = Int(absDays - Double(years) * 365.25)
            if remaining > 30 {
                return "\(sign)\(years) years, \(remaining) days"
            }
            return "\(sign)\(years) years"
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
    @Binding var speedLabel: String
    @Binding var activeSatCount: Int
    @Binding var isISSCamera: Bool
    @Binding var astroAge: String

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

        // Camera orbit state
        private var orbitAngleH: Float = 0
        private var orbitAngleV: Float = 0.5
        private var orbitDistance: Float = 22
        private var lastTime: TimeInterval = 0
        private var lastRecompute: TimeInterval = 0
        private let deadzone: Float = 0.1

        // Time state
        private var isPaused = false

        // ISS camera
        private var isISSCamera = false
        private var issOrbitAngleH: Float = 0  // local orbit around ISS view

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        init(_ parent: EarthOrbitSceneView) {
            self.parent = parent
        }

        /// Pressure-based speed curve: harder press = faster time, like a throttle.
        /// Trigger value 0.0-1.0 maps exponentially to speed.
        private func timeSpeed(pressure: Float) -> (daysPerSec: Double, label: String) {
            switch pressure {
            case ..<0.25: return (1,     "1 day/sec")
            case ..<0.50: return (30,    "1 month/sec")
            case ..<0.75: return (365,   "1 year/sec")
            case ..<0.90: return (3650,  "1 decade/sec")
            default:      return (36500, "1 century/sec")
            }
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
            let squareJust = parent.controller.squareJustPressed
            let circleJust = parent.controller.circleJustPressed

            guard parent.controller.isConnected else {
                // No controller: advance real-time every ~1 second (touch to pause)
                if !isPaused && abs(time - lastRecompute) > 1.0 {
                    lastRecompute = time
                    DispatchQueue.main.async { [weak self] in
                        guard let self, let scene = self.scene else { return }
                        let currentDate = Date().addingTimeInterval(self.parent.timeOffsetDays * 86400)
                        GeocentricScene.updatePositions(in: scene, date: currentDate, chart: self.parent.chart)
                    }
                }
                return
            }

            if let sv = scnView, sv.allowsCameraControl {
                sv.allowsCameraControl = false
            }

            // --- ISS Camera Mode ---
            if isISSCamera {
                // In ISS camera: left stick pans the view around
                if abs(lx) > deadzone { issOrbitAngleH += lx * dt * 1.5 }

                // Camera sits at ISS position, looking down at Earth
                if let issNode = scene?.rootNode.childNode(withName: "iss", recursively: false),
                   let cam = cameraNode {
                    let issPos = issNode.position
                    let dist = sqrt(issPos.x * issPos.x + issPos.y * issPos.y + issPos.z * issPos.z)
                    guard dist > 0.01 else { return }

                    // Slight inward offset so camera is just inside ISS, facing Earth
                    let nx = issPos.x / dist
                    let ny = issPos.y / dist
                    let nz = issPos.z / dist
                    cam.position = SCNVector3(
                        issPos.x - nx * 0.15,
                        issPos.y - ny * 0.15,
                        issPos.z - nz * 0.15
                    )

                    // Look at Earth, with left stick allowing slight pan
                    let lookX = sin(issOrbitAngleH) * 0.5
                    let lookZ = cos(issOrbitAngleH) * 0.5
                    cam.look(at: SCNVector3(lookX, 0, lookZ))
                }
            } else {
                // --- Free Camera ---
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

                if let cam = cameraNode {
                    let x = orbitDistance * cos(orbitAngleV) * sin(orbitAngleH)
                    let y = orbitDistance * sin(orbitAngleV)
                    let z = orbitDistance * cos(orbitAngleV) * cos(orbitAngleH)
                    cam.position = SCNVector3(x, y, z)
                    cam.look(at: SCNVector3(0, 0, 0))
                }
            }

            // --- Triggers: Pressure-Based Time Throttle ---
            let maxPressure = max(r2, l2)
            if maxPressure > deadzone {
                // Manual scrub — trigger controls speed
                let (speed, label) = timeSpeed(pressure: maxPressure)
                let forward = Double(r2) * speed * Double(dt)
                let backward = Double(l2) * speed * Double(dt)
                let timeDelta = forward - backward
                let newOffset = parent.timeOffsetDays + timeDelta

                DispatchQueue.main.async { [weak self] in
                    self?.parent.speedLabel = label
                }

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
            } else if !isPaused {
                // No trigger pressed — advance real-time
                let realDays = Double(dt) / 86400.0
                let newOffset = parent.timeOffsetDays + realDays

                if !parent.speedLabel.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.speedLabel = ""
                    }
                }

                // Update positions every ~1 second for real-time
                if abs(time - lastRecompute) > 1.0 {
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
            } else if !parent.speedLabel.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.speedLabel = ""
                }
            }

            // Cross: reset time
            if crossJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.timeOffsetDays = 0
                    self.parent.controller.crossJustPressed = false
                    self.parent.speedLabel = ""
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

            // Square: toggle ISS camera
            if squareJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.controller.squareJustPressed = false
                    self.isISSCamera.toggle()
                    self.parent.isISSCamera = self.isISSCamera
                    self.issOrbitAngleH = 0
                    if !self.isISSCamera {
                        self.orbitDistance = 22
                    }
                }
            }

            // Circle: pause / play
            if circleJust {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.controller.circleJustPressed = false
                    self.isPaused.toggle()
                    self.parent.speedLabel = self.isPaused ? "PAUSED" : ""
                }
            }
        }

        private func recomputePositions(offsetDays: Double) {
            let newDate = parent.initialDate.addingTimeInterval(offsetDays * 86400)
            parent.currentDateString = dateFormatter.string(from: newDate)

            // Show astrological age when time-traveling significantly
            let absDays = abs(offsetDays)
            if absDays > 365 {
                parent.astroAge = Precession.astrologicalAge(at: newDate)
            } else {
                parent.astroAge = ""
            }

            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }
                let birthData = BirthData(name: "Now", date: newDate,
                                          latitude: 0, longitude: 0, timeZoneOffset: 0)
                let newChart = EphemerisEngine.computeChart(birthData: birthData)
                let activeSats = SatelliteDatabase.active(at: newDate)
                DispatchQueue.main.async {
                    guard let scene = self.scene else { return }
                    GeocentricScene.updatePositions(in: scene, date: newDate, chart: newChart)
                    GeocentricScene.updateVisibility(in: scene, activeIDs: Set(activeSats.map { $0.id }))
                    self.parent.activeSatCount = activeSats.count
                }
            }
        }

        private func resetPositions() {
            guard let scene else { return }
            parent.currentDateString = ""
            parent.activeSatCount = SatelliteDatabase.all.count
            GeocentricScene.updatePositions(in: scene, date: parent.initialDate, chart: parent.chart)
            // Show all satellites at current time
            let allIDs = Set(SatelliteDatabase.all.map { $0.id })
            GeocentricScene.updateVisibility(in: scene, activeIDs: allIDs)
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

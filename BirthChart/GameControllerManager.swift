import GameController
import Combine

/// Manages DualSense controller connection and exposes live input state.
/// Input values are nonisolated(unsafe) so the SceneKit render thread can read them.
@MainActor
final class GameControllerManager: ObservableObject {
    @Published var connected = false

    // Stick/trigger values read from the render thread — nonisolated for perf.
    // Written only on main actor; read from render thread is a benign race on floats.
    nonisolated(unsafe) var leftStickX: Float = 0
    nonisolated(unsafe) var leftStickY: Float = 0
    nonisolated(unsafe) var rightStickX: Float = 0
    nonisolated(unsafe) var rightStickY: Float = 0
    nonisolated(unsafe) var leftTrigger: Float = 0
    nonisolated(unsafe) var rightTrigger: Float = 0
    nonisolated(unsafe) var isConnected: Bool = false

    // Button edge detection
    nonisolated(unsafe) var crossJustPressed = false
    nonisolated(unsafe) var triangleJustPressed = false
    nonisolated(unsafe) var squareJustPressed = false
    private var prevCross = false
    private var prevTriangle = false
    private var prevSquare = false

    private var controller: GCController?
    private var cancellables = Set<AnyCancellable>()

    init() {
        for c in GCController.controllers() {
            addController(c)
        }

        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] n in
                if let c = n.object as? GCController {
                    self?.addController(c)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.controller = nil
                self?.connected = false
                self?.isConnected = false
            }
            .store(in: &cancellables)
    }

    private func addController(_ c: GCController) {
        controller = c
        connected = true
        isConnected = true
        c.light?.color = GCColor(red: 0.2, green: 0.05, blue: 0.6)

        c.extendedGamepad?.valueChangedHandler = { [weak self] gp, _ in
            Task { @MainActor in
                guard let self else { return }
                self.leftStickX = gp.leftThumbstick.xAxis.value
                self.leftStickY = gp.leftThumbstick.yAxis.value
                self.rightStickX = gp.rightThumbstick.xAxis.value
                self.rightStickY = gp.rightThumbstick.yAxis.value
                self.leftTrigger = gp.leftTrigger.value
                self.rightTrigger = gp.rightTrigger.value

                let cross = gp.buttonA.isPressed
                let triangle = gp.buttonY.isPressed
                let square = gp.buttonX.isPressed
                self.crossJustPressed = cross && !self.prevCross
                self.triangleJustPressed = triangle && !self.prevTriangle
                self.squareJustPressed = square && !self.prevSquare
                self.prevCross = cross
                self.prevTriangle = triangle
                self.prevSquare = square
            }
        }
    }
}

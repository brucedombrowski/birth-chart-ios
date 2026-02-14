import SceneKit
import Foundation

/// Builds a 3D SceneKit scene showing the solar system at the moment of birth.
enum SolarSystemScene {

    // Planet visual properties: (color, radius in scene units, distance from sun in scene units)
    private struct PlanetVisuals {
        let color: UIColor
        let radius: CGFloat
        let orbitRadius: CGFloat  // log-scaled distance for visibility
    }

    private static let planetVisuals: [String: PlanetVisuals] = [
        "Sun":     PlanetVisuals(color: .systemYellow, radius: 1.5, orbitRadius: 0),
        "Mercury": PlanetVisuals(color: .lightGray,    radius: 0.2, orbitRadius: 3),
        "Venus":   PlanetVisuals(color: .systemOrange,  radius: 0.35, orbitRadius: 4.5),
        "Earth":   PlanetVisuals(color: .systemTeal,   radius: 0.4, orbitRadius: 6),
        "Mars":    PlanetVisuals(color: .systemRed,     radius: 0.3, orbitRadius: 8),
        "Jupiter": PlanetVisuals(color: .systemOrange,  radius: 0.9, orbitRadius: 11),
        "Saturn":  PlanetVisuals(color: .systemYellow,  radius: 0.8, orbitRadius: 14),
        "Uranus":  PlanetVisuals(color: .cyan,          radius: 0.5, orbitRadius: 17),
        "Neptune": PlanetVisuals(color: .systemBlue,    radius: 0.5, orbitRadius: 19),
        "Pluto":   PlanetVisuals(color: .brown,         radius: 0.15, orbitRadius: 21),
        "Moon":    PlanetVisuals(color: .white,         radius: 0.15, orbitRadius: 0.8),
    ]

    /// Build the complete 3D solar system scene.
    static func build(from chart: BirthChartResult) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.15, alpha: 1)
        scene.rootNode.addChildNode(ambientLight)

        // --- Sun ---
        let sunNode = createPlanetNode(name: "Sun", radius: 1.5, color: .systemYellow)
        sunNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunNode)

        // Sun glow light
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .omni
        sunLight.light?.color = UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1)
        sunLight.light?.intensity = 2000
        sunLight.light?.attenuationStartDistance = 0
        sunLight.light?.attenuationEndDistance = 50
        sunLight.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunLight)

        // --- Ecliptic plane ---
        let eclipticPlane = SCNFloor()
        eclipticPlane.reflectivity = 0
        let eclipticNode = SCNNode(geometry: eclipticPlane)
        eclipticNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.02)
        eclipticNode.geometry?.firstMaterial?.isDoubleSided = true
        eclipticNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(eclipticNode)

        // --- Planets ---
        // Earth is always placed at a fixed position; other planets relative to it
        // using their ecliptic longitude difference from Earth (Sun's longitude + 180°)
        let earthLon = chart.planets.first(where: { $0.name == "Sun" })
            .map { ($0.eclipticLongitude + 180).truncatingRemainder(dividingBy: 360) } ?? 0

        // Place Earth
        let earthVisuals = planetVisuals["Earth"]!
        let earthNode = createPlanetNode(name: "Earth", radius: earthVisuals.radius, color: earthVisuals.color)
        if let texImage = Bundle.main.path(forResource: "earth_texture", ofType: "jpg").flatMap { UIImage(contentsOfFile: $0) } {
            earthNode.geometry?.firstMaterial?.diffuse.contents = texImage
        }
        let earthAngle = earthLon * .pi / 180
        earthNode.position = SCNVector3(
            Float(earthVisuals.orbitRadius * cos(earthAngle)),
            0,
            Float(earthVisuals.orbitRadius * sin(earthAngle))
        )
        scene.rootNode.addChildNode(earthNode)
        addOrbitRing(to: scene.rootNode, radius: earthVisuals.orbitRadius)
        addLabel(to: earthNode, text: "Earth")

        // Place Moon relative to Earth
        if let moon = chart.planets.first(where: { $0.name == "Moon" }) {
            let moonVisuals = planetVisuals["Moon"]!
            let moonNode = createPlanetNode(name: "Moon", radius: moonVisuals.radius, color: moonVisuals.color)
            let moonAngle = moon.eclipticLongitude * .pi / 180
            moonNode.position = SCNVector3(
                earthNode.position.x + Float(moonVisuals.orbitRadius * cos(moonAngle)),
                0.1,
                earthNode.position.z + Float(moonVisuals.orbitRadius * sin(moonAngle))
            )
            scene.rootNode.addChildNode(moonNode)
            addLabel(to: moonNode, text: "Moon \(moon.sign.symbol)")
        }

        // Place other planets using their heliocentric positions
        let planetNames = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
        for planet in chart.planets where planetNames.contains(planet.name) {
            guard let visuals = planetVisuals[planet.name] else { continue }

            // Use the geocentric ecliptic longitude to place the planet
            // For visual purposes, use the ecliptic longitude to set the angle
            let angle = planet.eclipticLongitude * .pi / 180
            let node = createPlanetNode(name: planet.name, radius: visuals.radius, color: visuals.color)
            node.position = SCNVector3(
                Float(visuals.orbitRadius * cos(angle)),
                0,
                Float(visuals.orbitRadius * sin(angle))
            )
            scene.rootNode.addChildNode(node)
            addOrbitRing(to: scene.rootNode, radius: visuals.orbitRadius)

            let label = "\(planet.name) \(planet.sign.symbol)"
            addLabel(to: node, text: planet.isRetrograde ? "\(label) ℞" : label)

            // Saturn's ring
            if planet.name == "Saturn" {
                let ring = SCNTorus(ringRadius: CGFloat(visuals.radius * 1.8), pipeRadius: 0.05)
                ring.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
                let ringNode = SCNNode(geometry: ring)
                ringNode.eulerAngles.x = Float.pi * 0.15 // tilt
                node.addChildNode(ringNode)
            }
        }

        // --- Camera ---
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 200
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 25, 30)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    // MARK: - Live Update

    /// Update planet positions in an existing scene from a new chart computation.
    /// Animates nodes to their new positions for smooth time scrubbing.
    static func updatePositions(in scene: SCNScene, from chart: BirthChartResult) {
        let root = scene.rootNode

        let earthLon = chart.planets.first(where: { $0.name == "Sun" })
            .map { ($0.eclipticLongitude + 180).truncatingRemainder(dividingBy: 360) } ?? 0

        // Update Earth
        if let earthNode = root.childNode(withName: "Earth", recursively: true) {
            let visuals = planetVisuals["Earth"]!
            let angle = earthLon * .pi / 180
            let pos = SCNVector3(
                Float(visuals.orbitRadius * cos(angle)),
                0,
                Float(visuals.orbitRadius * sin(angle))
            )
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            earthNode.position = pos
            SCNTransaction.commit()

            // Update Moon relative to Earth
            if let moon = chart.planets.first(where: { $0.name == "Moon" }),
               let moonNode = root.childNode(withName: "Moon", recursively: true) {
                let moonVisuals = planetVisuals["Moon"]!
                let moonAngle = moon.eclipticLongitude * .pi / 180
                let moonPos = SCNVector3(
                    pos.x + Float(moonVisuals.orbitRadius * cos(moonAngle)),
                    0.1,
                    pos.z + Float(moonVisuals.orbitRadius * sin(moonAngle))
                )
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.1
                moonNode.position = moonPos
                SCNTransaction.commit()
                updateLabel(on: moonNode, text: "Moon \(moon.sign.symbol)")
            }
        }

        // Update other planets
        let planetNames = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
        for planet in chart.planets where planetNames.contains(planet.name) {
            guard let visuals = planetVisuals[planet.name],
                  let node = root.childNode(withName: planet.name, recursively: true) else { continue }

            let angle = planet.eclipticLongitude * .pi / 180
            let pos = SCNVector3(
                Float(visuals.orbitRadius * cos(angle)),
                0,
                Float(visuals.orbitRadius * sin(angle))
            )
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            node.position = pos
            SCNTransaction.commit()

            let label = "\(planet.name) \(planet.sign.symbol)"
            updateLabel(on: node, text: planet.isRetrograde ? "\(label) ℞" : label)
        }
    }

    /// Update the text label on a planet node.
    private static func updateLabel(on node: SCNNode, text: String) {
        for child in node.childNodes {
            if let textGeo = child.geometry as? SCNText {
                textGeo.string = text
                // Re-center
                let (min, max) = child.boundingBox
                let dx = (max.x - min.x) / 2
                child.position.x = -dx
                break
            }
        }
    }

    // MARK: - Helpers

    private static func createPlanetNode(name: String, radius: CGFloat, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 32
        sphere.firstMaterial?.diffuse.contents = color

        if name == "Sun" {
            sphere.firstMaterial?.emission.contents = UIColor.systemYellow
            sphere.firstMaterial?.emission.intensity = 0.8
        }

        let node = SCNNode(geometry: sphere)
        node.name = name
        return node
    }

    private static func addOrbitRing(to parent: SCNNode, radius: CGFloat) {
        let ring = SCNTorus(ringRadius: radius, pipeRadius: 0.02)
        ring.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.08)
        let ringNode = SCNNode(geometry: ring)
        parent.addChildNode(ringNode)
    }

    private static func addLabel(to node: SCNNode, text: String) {
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.font = UIFont.systemFont(ofSize: 0.5)
        textGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        textGeo.flatness = 0.1

        let textNode = SCNNode(geometry: textGeo)
        // Center the text
        let (min, max) = textNode.boundingBox
        let dx = (max.x - min.x) / 2
        textNode.position = SCNVector3(-dx, Float((node.geometry as? SCNSphere)?.radius ?? 0.5) + 0.3, 0)

        // Billboard constraint — always face camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        node.addChildNode(textNode)
    }
}

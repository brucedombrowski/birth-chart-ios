import SceneKit
import Foundation

/// Builds a 3D geocentric scene: Earth at center with satellites orbiting in LEO/MEO/GEO shells.
enum GeocentricScene {

    // Scene-unit scale factors (exaggerated for visibility)
    private static let earthRadius: Float = 2.0
    private static let leoScale: Float = 2.8    // LEO shell visual radius
    private static let meoScale: Float = 5.5    // MEO shell visual radius
    private static let geoScale: Float = 8.5    // GEO shell visual radius
    private static let moonScale: Float = 12.0  // Moon visual distance

    /// Map real altitude to scene radius.
    static func sceneRadius(altitudeKm: Double) -> Float {
        let earthR = 6371.0
        let ratio = (altitudeKm + earthR) / earthR // 1.0 = surface
        if ratio < 1.5 {
            // LEO: map 1.0-1.5 → earthRadius to leoScale
            let t = Float((ratio - 1.0) / 0.5)
            return earthRadius + t * (leoScale - earthRadius)
        } else if ratio < 4.0 {
            // MEO: map 1.5-4.0 → leoScale to meoScale
            let t = Float((ratio - 1.5) / 2.5)
            return leoScale + t * (meoScale - leoScale)
        } else {
            // GEO+: map 4.0-6.6 → meoScale to geoScale
            let t = min(1.0, Float((ratio - 4.0) / 2.6))
            return meoScale + t * (geoScale - meoScale)
        }
    }

    /// Build the geocentric 3D scene for a given date.
    static func build(date: Date, chart: BirthChartResult? = nil) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Directional "sun" light
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .directional
        sunLight.light?.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        sunLight.light?.intensity = 1500
        sunLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunLight)

        // --- Earth ---
        let earthSphere = SCNSphere(radius: CGFloat(earthRadius))
        earthSphere.segmentCount = 64
        if let texImage = Bundle.main.path(forResource: "earth_texture", ofType: "jpg").flatMap { UIImage(contentsOfFile: $0) } {
            earthSphere.firstMaterial?.diffuse.contents = texImage
        } else {
            earthSphere.firstMaterial?.diffuse.contents = UIColor.systemTeal
        }
        earthSphere.firstMaterial?.specular.contents = UIColor.white.withAlphaComponent(0.3)
        earthSphere.firstMaterial?.locksAmbientWithDiffuse = true
        // Tilt container (23.44° axial tilt) — never changes
        let tiltNode = SCNNode()
        tiltNode.name = "EarthTilt"
        tiltNode.eulerAngles.z = 23.44 * .pi / 180
        scene.rootNode.addChildNode(tiltNode)

        // Earth sphere rotates inside the tilt container
        let earthNode = SCNNode(geometry: earthSphere)
        earthNode.name = "Earth"
        // Rotation around polar axis using axis-angle (avoids gimbal lock)
        let angle = earthRotationAngle(at: date)
        earthNode.rotation = SCNVector4(0, 1, 0, angle)
        tiltNode.addChildNode(earthNode)

        // Earth "glow" ring (atmosphere)
        let atmoRing = SCNTorus(ringRadius: CGFloat(earthRadius + 0.05), pipeRadius: 0.08)
        atmoRing.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
        atmoRing.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.1)
        let atmoNode = SCNNode(geometry: atmoRing)
        scene.rootNode.addChildNode(atmoNode)

        // --- Orbital shells (visual guides) ---
        addShellRing(to: scene.rootNode, radius: CGFloat(leoScale), color: .green, label: "LEO")
        addShellRing(to: scene.rootNode, radius: CGFloat(meoScale), color: .orange, label: "MEO")
        addShellRing(to: scene.rootNode, radius: CGFloat(geoScale), color: .systemPurple, label: "GEO")

        // --- Satellites ---
        let satellites = SatelliteDatabase.all
        for sat in satellites {
            let pos = sat.position(at: date)
            let r = sceneRadius(altitudeKm: sat.altitudeKm)

            // Normalize position direction, then scale to scene radius
            let realR = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            guard realR > 0.01 else { continue }
            let nx = Float(pos.x / realR) * r
            let ny = Float(pos.z / realR) * r  // z → y (up in scene)
            let nz = Float(pos.y / realR) * r

            let satSize: CGFloat
            let satColor: UIColor
            let showLabel: Bool

            switch sat.orbitType {
            case "LEO":
                satSize = sat.constellation == nil ? 0.06 : 0.04
                satColor = sat.constellation == "Starlink" ? .white :
                           sat.constellation != nil ? .systemGreen : .systemYellow
                showLabel = sat.constellation == nil
            case "MEO":
                satSize = 0.07
                satColor = .systemOrange
                showLabel = sat.constellation == nil
            case "GEO":
                satSize = 0.08
                satColor = .systemPurple
                showLabel = true
            default:
                satSize = 0.05
                satColor = .white
                showLabel = false
            }

            let satNode = createSatelliteNode(name: sat.id, size: satSize, color: satColor)
            satNode.position = SCNVector3(nx, ny, nz)
            scene.rootNode.addChildNode(satNode)

            if showLabel {
                addLabel(to: satNode, text: "\(sat.icon) \(sat.name)", size: 0.25)
            }

            // ISS AOS (Acquisition of Signal) cone — footprint on Earth
            if sat.id == "iss" {
                addAOSCone(to: satNode, satPosition: SCNVector3(nx, ny, nz))
            }
        }

        // --- Moon ---
        if let moon = chart?.planets.first(where: { $0.name == "Moon" }) {
            let moonAngle = moon.eclipticLongitude * .pi / 180
            let moonNode = SCNNode(geometry: SCNSphere(radius: 0.5))
            moonNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            moonNode.name = "Moon"
            moonNode.position = SCNVector3(
                moonScale * cos(Float(moonAngle)),
                0.5,
                moonScale * sin(Float(moonAngle))
            )
            scene.rootNode.addChildNode(moonNode)
            addLabel(to: moonNode, text: "Moon \(moon.sign.symbol)", size: 0.4)
        }

        // --- Camera ---
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 200
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 12, 18)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    /// Update satellite positions for time scrubbing.
    static func updatePositions(in scene: SCNScene, date: Date, chart: BirthChartResult?) {
        let root = scene.rootNode
        let satellites = SatelliteDatabase.all

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1

        for sat in satellites {
            guard let node = root.childNode(withName: sat.id, recursively: false) else { continue }
            let pos = sat.position(at: date)
            let r = sceneRadius(altitudeKm: sat.altitudeKm)
            let realR = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            guard realR > 0.01 else { continue }
            let newPos = SCNVector3(
                Float(pos.x / realR) * r,
                Float(pos.z / realR) * r,
                Float(pos.y / realR) * r
            )
            node.position = newPos

            // Update ISS AOS cone direction
            if sat.id == "iss", let cone = node.childNode(withName: "aos-cone", recursively: false) {
                let dir = SCNVector3(-newPos.x, -newPos.y, -newPos.z)
                let len = sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
                if len > 0.01 {
                    cone.look(at: SCNVector3(0, 0, 0))
                    cone.eulerAngles.x += .pi / 2
                }
            }
        }

        // Rotate Earth (axis-angle, no gimbal lock)
        if let earthNode = root.childNode(withName: "Earth", recursively: true) {
            let angle = earthRotationAngle(at: date)
            earthNode.rotation = SCNVector4(0, 1, 0, angle)
        }

        // Update Moon
        if let moon = chart?.planets.first(where: { $0.name == "Moon" }),
           let moonNode = root.childNode(withName: "Moon", recursively: false) {
            let moonAngle = moon.eclipticLongitude * .pi / 180
            moonNode.position = SCNVector3(
                moonScale * cos(Float(moonAngle)),
                0.5,
                moonScale * sin(Float(moonAngle))
            )
        }

        SCNTransaction.commit()
    }

    /// Show/hide satellite nodes based on which satellites are active at the current date.
    /// Satellites launched after the viewed date are hidden — rewind to 1957 and watch the sky empty.
    static func updateVisibility(in scene: SCNScene, activeIDs: Set<String>) {
        let allSats = SatelliteDatabase.all
        let allIDs = Set(allSats.map { $0.id })
        let root = scene.rootNode

        for id in allIDs {
            guard let node = root.childNode(withName: id, recursively: false) else { continue }
            let shouldShow = activeIDs.contains(id)
            if node.isHidden != !shouldShow {
                node.isHidden = !shouldShow
            }
        }
    }

    // MARK: - Helpers

    private static func createSatelliteNode(name: String, size: CGFloat, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: size)
        sphere.segmentCount = 8
        sphere.firstMaterial?.diffuse.contents = color
        sphere.firstMaterial?.emission.contents = color.withAlphaComponent(0.5)
        let node = SCNNode(geometry: sphere)
        node.name = name
        return node
    }

    private static func addShellRing(to parent: SCNNode, radius: CGFloat, color: UIColor, label: String) {
        let ring = SCNTorus(ringRadius: radius, pipeRadius: 0.015)
        ring.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.12)
        ring.firstMaterial?.emission.contents = color.withAlphaComponent(0.05)
        let node = SCNNode(geometry: ring)
        node.name = "shell-\(label)"
        parent.addChildNode(node)
    }

    private static func addLabel(to node: SCNNode, text: String, size: CGFloat) {
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.font = UIFont.systemFont(ofSize: size)
        textGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        textGeo.flatness = 0.1

        let textNode = SCNNode(geometry: textGeo)
        let (min, max) = textNode.boundingBox
        let dx = (max.x - min.x) / 2
        textNode.position = SCNVector3(-dx, Float(size) + 0.1, 0)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        node.addChildNode(textNode)
    }

    /// Earth rotation angle from sidereal time.
    /// One full rotation every 23h 56m 4.1s (sidereal day = 86164.1 seconds).
    /// Returns raw accumulated angle (no modulo) to avoid animation jitter at wrap.
    private static func earthRotationAngle(at date: Date) -> Float {
        let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                   timeZone: TimeZone(identifier: "UTC"),
                                   year: 2000, month: 1, day: 1,
                                   hour: 12, minute: 0, second: 0).date!
        let secondsSinceJ2000 = date.timeIntervalSince(j2000)
        let siderealDay = 86164.0905 // seconds
        return Float(secondsSinceJ2000 / siderealDay * 2.0 * .pi)
    }

    /// Add ISS AOS (Acquisition of Signal) cone showing the ground footprint.
    /// At 420km, the ISS can see ~2,300km to the horizon in every direction.
    private static func addAOSCone(to satNode: SCNNode, satPosition: SCNVector3) {
        // Cone from ISS pointing toward Earth center
        // Half-angle of visibility: arccos(R_earth / (R_earth + h)) ≈ 20.4° at 420km
        // In scene units, the cone extends from the satellite to near Earth's surface
        let distToEarth = sqrt(satPosition.x * satPosition.x +
                               satPosition.y * satPosition.y +
                               satPosition.z * satPosition.z)
        let coneHeight = distToEarth - earthRadius
        guard coneHeight > 0.1 else { return }

        // The footprint radius on Earth at 420km is ~2300km
        // Half angle ≈ 20°, so base radius = height * tan(20°) ≈ 0.364 * height
        let coneBaseRadius = coneHeight * 0.36

        let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(coneBaseRadius), height: CGFloat(coneHeight))
        cone.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.08)
        cone.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.04)
        cone.firstMaterial?.isDoubleSided = true
        cone.firstMaterial?.transparency = 0.3

        let coneNode = SCNNode(geometry: cone)
        coneNode.name = "aos-cone"

        // Point cone toward Earth center (0,0,0)
        // SCNCone grows along +Y by default, with the tip at +height/2
        coneNode.position = SCNVector3(0, -coneHeight / 2 - 0.06, 0)
        coneNode.look(at: SCNVector3(-satPosition.x, -satPosition.y, -satPosition.z))
        coneNode.eulerAngles.x += .pi / 2

        satNode.addChildNode(coneNode)

        // Also add a spotlight for dramatic ground illumination
        let spotLight = SCNNode()
        spotLight.light = SCNLight()
        spotLight.light?.type = .spot
        spotLight.light?.color = UIColor.systemYellow.withAlphaComponent(0.3)
        spotLight.light?.intensity = 200
        spotLight.light?.spotInnerAngle = 5
        spotLight.light?.spotOuterAngle = 25
        spotLight.light?.attenuationStartDistance = 0
        spotLight.light?.attenuationEndDistance = CGFloat(distToEarth)
        spotLight.look(at: SCNVector3(0, 0, 0))
        satNode.addChildNode(spotLight)
    }
}

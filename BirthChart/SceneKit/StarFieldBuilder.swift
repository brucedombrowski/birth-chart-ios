import SceneKit
import Foundation

/// Builds a celestial sphere with stars and constellation stick figures.
/// The sphere rotates with precession of the equinoxes over millennia.
enum StarFieldBuilder {

    /// Radius of the celestial sphere in scene units (far background).
    private static let sphereRadius: Float = 80.0

    /// Convert equatorial coordinates (RA, Dec) to 3D position on the celestial sphere.
    /// Accounts for precession by rotating around the ecliptic pole.
    static func position(raDeg: Double, decDeg: Double, precessionRad: Double = 0) -> SCNVector3 {
        let ra = raDeg * .pi / 180
        let dec = decDeg * .pi / 180

        // Position on celestial sphere (J2000)
        var x = Double(sphereRadius) * cos(dec) * cos(ra)
        var y = Double(sphereRadius) * sin(dec)
        var z = Double(sphereRadius) * cos(dec) * sin(ra)

        // Apply precession: rotate around the ecliptic pole axis.
        // The ecliptic pole is tilted 23.44° from the celestial pole.
        // Simplified: rotate around the Y-axis (celestial pole) by precession angle.
        // This approximation works well for visualization.
        if abs(precessionRad) > 0.0001 {
            let cosP = cos(precessionRad)
            let sinP = sin(precessionRad)
            let xNew = x * cosP - z * sinP
            let zNew = x * sinP + z * cosP
            x = xNew
            z = zNew
        }

        return SCNVector3(Float(x), Float(y), Float(z))
    }

    /// Build the star field and constellation lines. Returns a parent node for the whole celestial sphere.
    static func build(at date: Date) -> SCNNode {
        let parentNode = SCNNode()
        parentNode.name = "CelestialSphere"

        let precession = Precession.angle(at: date)
        let stars = StarDatabase.allStars
        let constellations = StarDatabase.constellations

        // Build star ID → position lookup
        var starPositions: [String: SCNVector3] = [:]
        for star in stars {
            starPositions[star.id] = position(raDeg: star.raDeg, decDeg: star.decDeg,
                                              precessionRad: precession)
        }

        // --- Stars ---
        for star in stars {
            guard let pos = starPositions[star.id] else { continue }

            // Size based on magnitude (brighter = larger)
            let size: CGFloat
            let brightness: CGFloat
            switch star.magnitude {
            case ..<0:
                size = 0.5
                brightness = 1.0
            case ..<1:
                size = 0.35
                brightness = 0.9
            case ..<2:
                size = 0.25
                brightness = 0.8
            case ..<3:
                size = 0.18
                brightness = 0.6
            default:
                size = 0.12
                brightness = 0.4
            }

            let sphere = SCNSphere(radius: size)
            sphere.segmentCount = 6
            sphere.firstMaterial?.diffuse.contents = UIColor.white
            sphere.firstMaterial?.emission.contents = UIColor(white: brightness, alpha: 1)
            sphere.firstMaterial?.emission.intensity = 1.0

            let starNode = SCNNode(geometry: sphere)
            starNode.name = "star-\(star.id)"
            starNode.position = pos
            parentNode.addChildNode(starNode)
        }

        // --- Constellation Lines ---
        for constellation in constellations {
            for line in constellation.lines {
                guard line.count == 2,
                      let p1 = starPositions[line[0]],
                      let p2 = starPositions[line[1]] else { continue }

                let lineNode = createLine(from: p1, to: p2,
                                          color: UIColor.white.withAlphaComponent(0.15))
                lineNode.name = "cline-\(constellation.abbreviation)"
                parentNode.addChildNode(lineNode)
            }

            // Constellation label
            if let labelPos = starPositions[constellation.labelStarId] {
                let textGeo = SCNText(string: constellation.name, extrusionDepth: 0)
                textGeo.font = UIFont.systemFont(ofSize: 0.8)
                textGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.25)
                textGeo.flatness = 0.2

                let textNode = SCNNode(geometry: textGeo)
                let (minB, maxB) = textNode.boundingBox
                let dx = (maxB.x - minB.x) / 2
                textNode.position = SCNVector3(labelPos.x, labelPos.y + 1.5, labelPos.z)
                textNode.pivot = SCNMatrix4MakeTranslation(dx, 0, 0)

                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .all
                textNode.constraints = [billboard]
                textNode.name = "clabel-\(constellation.abbreviation)"
                parentNode.addChildNode(textNode)
            }
        }

        // --- Vernal Equinox Marker ---
        // The 0° Aries point (vernal equinox in tropical zodiac)
        // In J2000, this is at RA=0, Dec=0, but precesses over time
        let vernalPos = position(raDeg: 0, decDeg: 0, precessionRad: 0) // fixed to ecliptic
        let vernalMarker = SCNSphere(radius: 0.6)
        vernalMarker.segmentCount = 8
        vernalMarker.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
        vernalMarker.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.3)
        let vernalNode = SCNNode(geometry: vernalMarker)
        vernalNode.name = "vernal-equinox"
        vernalNode.position = vernalPos
        parentNode.addChildNode(vernalNode)

        let vLabel = SCNText(string: "Vernal Equinox (0° Aries)", extrusionDepth: 0)
        vLabel.font = UIFont.systemFont(ofSize: 0.6)
        vLabel.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.4)
        let vLabelNode = SCNNode(geometry: vLabel)
        let (vMin, vMax) = vLabelNode.boundingBox
        vLabelNode.pivot = SCNMatrix4MakeTranslation((vMax.x - vMin.x) / 2, 0, 0)
        vLabelNode.position = SCNVector3(vernalPos.x, vernalPos.y + 1.5, vernalPos.z)
        let vBillboard = SCNBillboardConstraint()
        vBillboard.freeAxes = .all
        vLabelNode.constraints = [vBillboard]
        vLabelNode.name = "vernal-label"
        parentNode.addChildNode(vLabelNode)

        return parentNode
    }

    /// Update all star and constellation positions for precession at a new date.
    static func updatePrecession(node: SCNNode, date: Date) {
        let precession = Precession.angle(at: date)
        let stars = StarDatabase.allStars

        var starPositions: [String: SCNVector3] = [:]
        for star in stars {
            let pos = position(raDeg: star.raDeg, decDeg: star.decDeg,
                               precessionRad: precession)
            starPositions[star.id] = pos

            if let starNode = node.childNode(withName: "star-\(star.id)", recursively: false) {
                starNode.position = pos
            }
        }

        // Update constellation lines
        let constellations = StarDatabase.constellations
        // Remove old lines and labels, rebuild
        node.enumerateChildNodes { child, _ in
            if let name = child.name, (name.hasPrefix("cline-") || name.hasPrefix("clabel-")) {
                child.removeFromParentNode()
            }
        }

        for constellation in constellations {
            for line in constellation.lines {
                guard line.count == 2,
                      let p1 = starPositions[line[0]],
                      let p2 = starPositions[line[1]] else { continue }
                let lineNode = createLine(from: p1, to: p2,
                                          color: UIColor.white.withAlphaComponent(0.15))
                lineNode.name = "cline-\(constellation.abbreviation)"
                node.addChildNode(lineNode)
            }

            if let labelPos = starPositions[constellation.labelStarId] {
                let textGeo = SCNText(string: constellation.name, extrusionDepth: 0)
                textGeo.font = UIFont.systemFont(ofSize: 0.8)
                textGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.25)
                textGeo.flatness = 0.2

                let textNode = SCNNode(geometry: textGeo)
                let (minB, maxB) = textNode.boundingBox
                let dx = (maxB.x - minB.x) / 2
                textNode.position = SCNVector3(labelPos.x, labelPos.y + 1.5, labelPos.z)
                textNode.pivot = SCNMatrix4MakeTranslation(dx, 0, 0)

                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .all
                textNode.constraints = [billboard]
                textNode.name = "clabel-\(constellation.abbreviation)"
                node.addChildNode(textNode)
            }
        }
    }

    // MARK: - Helpers

    /// Create a thin cylinder between two 3D points to represent a constellation line.
    private static func createLine(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let length = sqrt(dx * dx + dy * dy + dz * dz)

        let cylinder = SCNCylinder(radius: 0.04, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.emission.contents = color

        let lineNode = SCNNode(geometry: cylinder)
        // Position at midpoint
        lineNode.position = SCNVector3(
            (from.x + to.x) / 2,
            (from.y + to.y) / 2,
            (from.z + to.z) / 2
        )

        // Orient cylinder to connect the two points
        // SCNCylinder is along Y axis by default
        let dir = SCNVector3(dx, dy, dz)
        let up = SCNVector3(0, 1, 0)
        let cross = SCNVector3(
            up.y * dir.z - up.z * dir.y,
            up.z * dir.x - up.x * dir.z,
            up.x * dir.y - up.y * dir.x
        )
        let crossLen = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
        let dot = up.x * dir.x + up.y * dir.y + up.z * dir.z

        if crossLen > 0.0001 {
            let angle = atan2(crossLen, dot)
            lineNode.rotation = SCNVector4(
                cross.x / crossLen,
                cross.y / crossLen,
                cross.z / crossLen,
                angle
            )
        } else if dot < 0 {
            lineNode.eulerAngles.x = .pi
        }

        return lineNode
    }
}

import Combine
import SceneKit
import SwiftUI

final class GameSceneController: NSObject, ObservableObject, SCNSceneRendererDelegate {
    @Published private(set) var status = "Loading city"
    @Published private(set) var isReady = false
    @Published var activeInterior: InteriorDestination?

    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let playerRoot = SCNNode()
    private var cityRoot: SCNNode?
    private var interactions: CityInteractionManifest?
    private var trafficController: TrafficController?
    private var movement = SIMD2<Float>.zero
    private var lastUpdate: TimeInterval?
    private var elapsedTime: TimeInterval = 0
    private var lastDoorActivation: TimeInterval = -10
    private var idlePlayer: SCNAnimationPlayer?
    private var walkPlayer: SCNAnimationPlayer?
    private var isWalking = false
    private var fadedBuildings = Set<String>()
    private var buildingOcclusionNodes: [String: [SCNNode]] = [:]
    private var activeDoorNode: SCNNode?
    private var activeDoorMaterials: [SCNMaterial]?
    private var activeDoorID: Int?
    private var suppressedDoorID: Int?

    // Looking from the south-east makes the north-west park sit high in frame,
    // while the city façades read down and left.
    private let cameraOffset = SIMD3<Float>(15.2, 29.45, 26.6)
    private let walkSpeed: Float = 8
    private let playerRadius: Float = 0.42

    override init() {
        super.init()
        configureScene()
    }

    func setInput(_ value: SIMD2<Float>) {
        movement = value
    }

    func interact() {
        guard let door = nearestDoor(maxDistance: 2.4) else {
            publishStatus("Find a building door")
            return
        }
        activate(door)
    }

    func dismissInterior() {
        suppressedDoorID = activeDoorID
        activeInterior = nil
        restoreActiveDoor()
        status = "City online"
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let delta = min(Float(time - (lastUpdate ?? time)), 1 / 20)
        lastUpdate = time
        elapsedTime = time
        trafficController?.update(deltaTime: delta, playerPosition: playerRoot.simdPosition)
        updatePlayer(deltaTime: delta)
        checkDoorTriggers()
        updateCamera(deltaTime: delta)
        updateBuildingOcclusion()
    }

    private func configureScene() {
        scene.background.contents = platformColor(red: 0.025, green: 0.035, blue: 0.06)
        scene.lightingEnvironment.intensity = 0.65
        scene.fogStartDistance = 75
        scene.fogEndDistance = 155
        scene.fogColor = platformColor(red: 0.07, green: 0.09, blue: 0.13)

        addLighting()
        addCamera()
        loadCity()
        loadGameplayData()
        loadPlayer()

        isReady = true
        status = "City online"
    }

    private func addLighting() {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1_500
        sun.temperature = 5_800
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 4
        sun.shadowColor = platformColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 0.32)

        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-1.05, -0.75, -0.25)
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 700
        ambient.color = platformColor(red: 0.72, green: 0.78, blue: 0.90)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func addCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 44
        camera.zNear = 0.1
        camera.zFar = 350
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = true
        camera.bloomIntensity = 0.18
        camera.bloomThreshold = 1.15
        cameraNode.camera = camera
        cameraNode.simdPosition = cameraOffset
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func loadCity() {
        guard let city = SCNScene(named: "FloatingCliffCity.usdz") else {
            status = "City asset missing"
            return
        }

        let container = SCNNode()
        container.name = "CITY"
        city.rootNode.childNodes.forEach { container.addChildNode($0) }
        scene.rootNode.addChildNode(container)
        cityRoot = container
    }

    private func loadGameplayData() {
        do {
            interactions = try GameplayDataLoader.interactions()
            if let cityRoot, let interactions {
                prepareBuildingOcclusionNodes(
                    cityRoot: cityRoot,
                    interactions: interactions
                )
                addBuildingLabels(for: interactions)
                trafficController = TrafficController(
                    cityRoot: cityRoot,
                    manifest: try GameplayDataLoader.traffic()
                )
            }
        } catch {
            status = "Gameplay data missing"
        }
    }

    private func addBuildingLabels(for interactions: CityInteractionManifest) {
        let labelsRoot = SCNNode()
        labelsRoot.name = "BUILDING_LABELS"

        for building in interactions.buildings {
            let bounds = building.sceneBounds
            let label: String
            switch building.interiorID {
            case "INTERIOR_018":
                label = "HOME"
            case "INTERIOR_017":
                label = "BURGER SHOP"
            default:
                label = building.interiorID.replacingOccurrences(of: "_", with: " ")
            }
            let plane = SCNPlane(width: 2.4, height: 0.6)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = makeBuildingLabelTexture(
                text: label,
                isHome: building.interiorID == "INTERIOR_018"
            )
            material.isDoubleSided = true
            material.writesToDepthBuffer = false
            plane.materials = [material]

            let node = SCNNode(geometry: plane)
            node.name = "LABEL_\(building.interiorID)"
            node.simdPosition = SIMD3<Float>(
                (bounds.minX + bounds.maxX) * 0.5,
                bounds.height + 1.15,
                (bounds.minZ + bounds.maxZ) * 0.5
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            node.constraints = [billboard]
            node.renderingOrder = 20
            labelsRoot.addChildNode(node)
        }

        scene.rootNode.addChildNode(labelsRoot)
    }

    private func makeBuildingLabelTexture(text: String, isHome: Bool) -> Any? {
        MainActor.assumeIsolated {
            let renderer = ImageRenderer(
                content: BuildingLabelCard(text: text, isHome: isHome)
                    .frame(width: 256, height: 64)
            )
            renderer.scale = 2
            #if os(macOS)
            return renderer.nsImage
            #else
            return renderer.uiImage
            #endif
        }
    }

    private func loadPlayer() {
        playerRoot.name = "PLAYER"
        // Begin on the sidewalk just outside Home (Interior 018), beyond its
        // automatic door trigger so launch does not immediately enter it.
        playerRoot.simdPosition = SIMD3<Float>(-48, 0.55, -41.75)
        scene.rootNode.addChildNode(playerRoot)

        if let playerScene = SCNScene(named: "PlayerIdle.usdz") {
            let model = SCNNode()
            playerScene.rootNode.childNodes.forEach { model.addChildNode($0) }
            normalizePlayer(model)
            playerRoot.addChildNode(model)
            configureAnimations(in: model)
        } else {
            playerRoot.addChildNode(makePlaceholderPlayer())
            status = "Player placeholder active"
        }
    }

    private func normalizePlayer(_ model: SCNNode) {
        let bounds = model.boundingBox
        // Blender's player USD is Z-up. Rotate it into SceneKit's Y-up world
        // before sizing it to a consistent gameplay height.
        let height = max(bounds.max.z - bounds.min.z, 0.001)
        let scale = 1.98 / height
        model.scale = SCNVector3(scale, scale, scale)
        model.eulerAngles.x = -.pi / 2
        model.position.y = -bounds.min.z * scale
        model.name = "PLAYER_MODEL"
    }

    private func configureAnimations(in model: SCNNode) {
        guard let targetArmature = model.childNode(withName: "Armature", recursively: true) else {
            status = "Player rig missing"
            return
        }

        if let key = targetArmature.animationKeys.first,
           let source = targetArmature.animationPlayer(forKey: key) {
            targetArmature.removeAllAnimations()
            let animation = source.animation
            animation.repeatCount = .greatestFiniteMagnitude
            animation.blendInDuration = 0.18
            animation.blendOutDuration = 0.18
            idlePlayer = SCNAnimationPlayer(animation: animation)
            targetArmature.addAnimationPlayer(idlePlayer!, forKey: "idle")
        }

        if let walkScene = SCNScene(named: "PlayerWalk.usdz"),
           let walkArmature = walkScene.rootNode.childNode(withName: "Armature", recursively: true),
           let key = walkArmature.animationKeys.first,
           let source = walkArmature.animationPlayer(forKey: key) {
            let animation = source.animation
            animation.repeatCount = .greatestFiniteMagnitude
            animation.blendInDuration = 0.14
            animation.blendOutDuration = 0.14
            walkPlayer = SCNAnimationPlayer(animation: animation)
            targetArmature.addAnimationPlayer(walkPlayer!, forKey: "walk")
        }

        idlePlayer?.play()
    }

    private func makePlaceholderPlayer() -> SCNNode {
        let body = SCNCapsule(capRadius: 0.38, height: 1.75)
        body.firstMaterial?.diffuse.contents = platformColor(red: 0.55, green: 0.95, blue: 0.18)
        body.firstMaterial?.roughness.contents = 0.72
        let node = SCNNode(geometry: body)
        node.position.y = 0.88
        return node
    }

    private func updatePlayer(deltaTime: Float) {
        let shouldWalk = simd_length_squared(movement) > 0.0025
        updateLocomotionAnimation(isMoving: shouldWalk)
        guard shouldWalk else { return }

        let input = simd_normalize(movement)
        let cameraForward = simd_normalize(
            SIMD3<Float>(-cameraOffset.x, 0, -cameraOffset.z)
        )
        let cameraRight = SIMD3<Float>(-cameraForward.z, 0, cameraForward.x)
        let direction = simd_normalize(cameraRight * input.x + cameraForward * input.y)

        let displacement = direction * walkSpeed * deltaTime
        playerRoot.simdPosition = resolvedPlayerPosition(
            from: playerRoot.simdPosition,
            displacement: displacement
        )
        let targetYaw = atan2(direction.x, direction.z)
        playerRoot.simdOrientation = simd_slerp(
            playerRoot.simdOrientation,
            simd_quatf(angle: targetYaw, axis: SIMD3<Float>(0, 1, 0)),
            min(deltaTime * 12, 1)
        )
    }

    private func updateLocomotionAnimation(isMoving: Bool) {
        guard isMoving != isWalking else { return }
        isWalking = isMoving

        if isMoving {
            idlePlayer?.stop(withBlendOutDuration: 0.16)
            walkPlayer?.play()
        } else {
            walkPlayer?.stop(withBlendOutDuration: 0.16)
            idlePlayer?.play()
        }
    }

    private func updateCamera(deltaTime: Float) {
        let targetPosition = playerRoot.simdPosition + cameraOffset
        let blend = min(deltaTime * 5, 1)
        cameraNode.simdPosition = simd_mix(cameraNode.simdPosition, targetPosition, SIMD3<Float>(repeating: blend))
        let forward = simd_normalize(SIMD3<Float>(-cameraOffset.x, 0, -cameraOffset.z))
        let compositionTarget = playerRoot.simdPosition + forward * 6 + SIMD3<Float>(0, 1.1, 0)
        cameraNode.look(at: SCNVector3(compositionTarget))
    }

    private func resolvedPlayerPosition(
        from current: SIMD3<Float>,
        displacement: SIMD3<Float>
    ) -> SIMD3<Float> {
        var target = current + displacement
        target.x = min(max(target.x, -61), 61)
        target.z = min(max(target.z, -61), 61)

        if canOccupy(target, from: current) { return target }

        let xOnly = SIMD3<Float>(target.x, current.y, current.z)
        let zOnly = SIMD3<Float>(current.x, current.y, target.z)
        let canMoveX = canOccupy(xOnly, from: current)
        let canMoveZ = canOccupy(zOnly, from: current)

        if canMoveX && canMoveZ {
            return abs(displacement.x) > abs(displacement.z) ? xOnly : zOnly
        }
        if canMoveX { return xOnly }
        if canMoveZ { return zOnly }
        return current
    }

    private func canOccupy(
        _ position: SIMD3<Float>,
        from current: SIMD3<Float>
    ) -> Bool {
        if interactions?.buildings.contains(where: {
            $0.sceneBounds.expanded(by: playerRadius).contains(position)
        }) == true {
            return false
        }

        return trafficController?.allowsPlayerMovement(
            from: current,
            to: position,
            radius: playerRadius
        ) ?? true
    }

    private func checkDoorTriggers() {
        let door = interactions?.doors.first(where: {
            $0.sceneTrigger.contains(playerRoot.simdPosition)
        })

        if door == nil {
            suppressedDoorID = nil
            return
        }

        guard activeInterior == nil,
              elapsedTime - lastDoorActivation >= 0.75,
              door?.doorID != suppressedDoorID,
              let door else { return }
        activate(door)
    }

    private func nearestDoor(maxDistance: Float) -> DoorRecord? {
        interactions?.doors
            .map { door -> (DoorRecord, Float) in
                let trigger = door.sceneTrigger
                let center = SIMD2<Float>(
                    (trigger.minX + trigger.maxX) * 0.5,
                    (trigger.minZ + trigger.maxZ) * 0.5
                )
                let player = SIMD2<Float>(
                    playerRoot.simdPosition.x,
                    playerRoot.simdPosition.z
                )
                return (door, simd_distance(center, player))
            }
            .filter { $0.1 <= maxDistance }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func activate(_ door: DoorRecord) {
        lastDoorActivation = elapsedTime
        restoreActiveDoor()
        activeDoorID = door.doorID

        if let building = cityRoot?.childNode(
            withName: String(format: "BUILDING_%03d", door.buildingID),
            recursively: true
        ), let doorNode = building.firstDescendant(where: {
            $0.name?.hasPrefix("South_Facing_Door") == true
        }) {
            activeDoorNode = doorNode
            let geometryNodes = doorNode.geometryDescendants
            activeDoorMaterials = geometryNodes.flatMap {
                $0.geometry?.materials.compactMap { $0.copy() as? SCNMaterial } ?? []
            }
            geometryNodes.forEach { node in
                guard let geometry = node.geometry else { return }
                geometry.materials = geometry.materials.map { source in
                    let material = source.copy() as! SCNMaterial
                    material.diffuse.contents = platformColor(red: 0.01, green: 0.01, blue: 0.012)
                    material.emission.contents = platformColor(red: 0, green: 0, blue: 0)
                    return material
                }
            }
        }

        let destination = InteriorDestination(
            id: door.interiorID,
            buildingID: door.buildingID
        )
        DispatchQueue.main.async { [weak self] in
            self?.status = "Entering \(door.interiorID)"
            self?.activeInterior = destination
        }
    }

    private func restoreActiveDoor() {
        guard let activeDoorNode, let activeDoorMaterials else { return }
        var materialIndex = 0
        for node in activeDoorNode.geometryDescendants {
            guard let geometry = node.geometry else { continue }
            let count = geometry.materials.count
            guard materialIndex + count <= activeDoorMaterials.count else { break }
            geometry.materials = Array(
                activeDoorMaterials[materialIndex..<(materialIndex + count)]
            )
            materialIndex += count
        }
        self.activeDoorNode = nil
        self.activeDoorMaterials = nil
        self.activeDoorID = nil
    }

    private func prepareBuildingOcclusionNodes(
        cityRoot: SCNNode,
        interactions: CityInteractionManifest
    ) {
        var detachedRoofPieces: [SCNNode] = []
        cityRoot.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            if name.hasPrefix("Roof_Cap")
                || name.hasPrefix("Antenna")
                || name.hasPrefix("Landmark_Step")
                || name == "Landmark_Spire" {
                detachedRoofPieces.append(node)
            }
        }

        buildingOcclusionNodes = Dictionary(
            uniqueKeysWithValues: interactions.buildings.map { building in
                var nodes: [SCNNode] = []
                if let root = cityRoot.childNode(
                    withName: building.rootEntity,
                    recursively: true
                ) {
                    nodes.append(root)
                }

                let attachmentBounds = building.sceneBounds.expanded(by: 0.25)
                nodes.append(contentsOf: detachedRoofPieces.filter {
                    attachmentBounds.contains($0.simdWorldPosition)
                })
                return (building.rootEntity, nodes)
            }
        )
    }

    private func updateBuildingOcclusion() {
        guard let interactions else { return }
        let camera = cameraNode.simdWorldPosition
        let player = playerRoot.simdWorldPosition + SIMD3<Float>(0, 1.0, 0)
        var blocked = Set<String>()

        for building in interactions.buildings {
            guard let entry = building.sceneBounds.segmentEntry(from: camera, to: player),
                  entry > 0.03, entry < 0.96 else { continue }
            // The camera is intentionally steep and composed ahead of the
            // player. Testing against wall height caused short buildings and
            // their detached roof caps to be skipped even while they visibly
            // covered the player. A footprint intersection gives consistent
            // top-down occlusion for every building height.
            blocked.insert(building.rootEntity)
        }

        for name in blocked.subtracting(fadedBuildings) {
            buildingOcclusionNodes[name]?.forEach {
                $0.runAction(.fadeOpacity(to: 0.08, duration: 0.16))
            }
        }
        for name in fadedBuildings.subtracting(blocked) {
            buildingOcclusionNodes[name]?.forEach {
                $0.runAction(.fadeOpacity(to: 1, duration: 0.16))
            }
        }
        fadedBuildings = blocked
    }

    private func publishStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in self?.status = text }
    }

    private func platformColor(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1
    ) -> Any {
        #if os(macOS)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #else
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }

}

private struct BuildingLabelCard: View {
    let text: String
    let isHome: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isHome ? 23 : 18, weight: .bold, design: .rounded))
            .foregroundStyle(
                isHome
                    ? Color(red: 0.65, green: 1, blue: 0.22)
                    : Color(red: 0.82, green: 0.9, blue: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(red: 0.02, green: 0.035, blue: 0.06).opacity(0.94),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(
                        isHome
                            ? Color(red: 0.65, green: 1, blue: 0.22).opacity(0.8)
                            : Color.white.opacity(0.22),
                        lineWidth: isHome ? 2.5 : 1.5
                    )
            }
            .padding(3)
    }
}

private extension SCNNode {
    var geometryDescendants: [SCNNode] {
        var nodes: [SCNNode] = []
        if geometry != nil { nodes.append(self) }
        enumerateChildNodes { node, _ in
            if node.geometry != nil { nodes.append(node) }
        }
        return nodes
    }

    func firstDescendant(where predicate: (SCNNode) -> Bool) -> SCNNode? {
        if predicate(self) { return self }
        for child in childNodes {
            if let match = child.firstDescendant(where: predicate) { return match }
        }
        return nil
    }
}

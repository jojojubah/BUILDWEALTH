import SceneKit
import simd

final class TrafficController {
    private static let speedScale: Float = 0.8

    private struct Vehicle {
        let node: SCNNode
        let path: TrafficPathRecord
        let topSpeed: Float
        let wheels: [SCNNode]
        var segment: Int
        var progress: Float
        var speed: Float
    }

    private var vehicles: [Vehicle] = []
    private let wheelRadius: Float = 0.34
    private let playerHardClearance: Float = 1.75
    private let stoppedVehicleSpacing: Float = 3.8
    private let fullSpeedVehicleSpacing: Float = 8.0
    private let playerLaneHalfWidth: Float = 1.65
    private let playerStopDistance: Float = 2.6
    private let playerYieldDistance: Float = 5.2

    init(cityRoot: SCNNode, manifest: TrafficManifest) {
        for record in manifest.vehicles {
            guard let node = cityRoot.childNode(withName: record.name, recursively: true),
                  let match = Self.closestPath(
                    to: SIMD2<Float>(record.position[0], record.position[1]),
                    paths: manifest.paths
                  ) else { continue }

            let wheels = node.childNodes(passingTest: {
                $0.name?.hasPrefix("Vehicle_Wheel") == true
            })
            var vehicle = Vehicle(
                node: node,
                path: match.path,
                topSpeed: min(record.maxSpeed, match.path.recommendedSpeed) * Self.speedScale,
                wheels: wheels,
                segment: match.segment,
                progress: match.progress,
                speed: 0
            )
            applyTransform(to: &vehicle)
            vehicles.append(vehicle)
        }
    }

    func update(deltaTime: Float, playerPosition: SIMD3<Float>) {
        guard deltaTime > 0 else { return }
        let step = min(deltaTime, 1.0 / 20.0)
        let pathDistances = vehicles.map(distanceAlongPath)

        for index in vehicles.indices {
            var vehicle = vehicles[index]
            let direction = segmentDirection(for: vehicle)
            let worldPosition = SIMD2<Float>(
                vehicle.node.simdWorldPosition.x,
                vehicle.node.simdWorldPosition.z
            )
            let playerDelta = SIMD2<Float>(
                playerPosition.x - worldPosition.x,
                playerPosition.z - worldPosition.y
            )

            var targetSpeed = vehicle.topSpeed

            if let gap = forwardGap(
                for: index,
                pathDistances: pathDistances
            ) {
                let spacingFactor = min(
                    max(
                        (gap - stoppedVehicleSpacing)
                            / (fullSpeedVehicleSpacing - stoppedVehicleSpacing),
                        0
                    ),
                    1
                )
                targetSpeed = min(targetSpeed, vehicle.topSpeed * spacingFactor)
            }

            targetSpeed = min(
                targetSpeed,
                playerYieldSpeed(
                    for: vehicle,
                    playerDelta: playerDelta,
                    direction: direction.sceneDirection
                )
            )

            let acceleration: Float = targetSpeed < vehicle.speed ? 18 : 7
            vehicle.speed += min(abs(targetSpeed - vehicle.speed), acceleration * step)
                * (targetSpeed >= vehicle.speed ? 1 : -1)

            let distance = vehicle.speed * step
            let previousSegment = vehicle.segment
            let previousProgress = vehicle.progress
            advance(&vehicle, distance: distance)
            applyTransform(to: &vehicle)

            let movedCar = vehicle.node.simdWorldPosition
            let movedPlayerDelta = SIMD2<Float>(
                playerPosition.x - movedCar.x,
                playerPosition.z - movedCar.z
            )
            if simd_length(movedPlayerDelta) < playerHardClearance {
                vehicle.segment = previousSegment
                vehicle.progress = previousProgress
                vehicle.speed = 0
                applyTransform(to: &vehicle)
            } else {
                let wheelTurn = distance / wheelRadius
                vehicle.wheels.forEach { wheel in
                    var rotation = wheel.simdEulerAngles
                    rotation.y += wheelTurn
                    wheel.simdEulerAngles = rotation
                }
            }
            vehicles[index] = vehicle
        }
    }

    private func playerYieldSpeed(
        for vehicle: Vehicle,
        playerDelta: SIMD2<Float>,
        direction: SIMD2<Float>
    ) -> Float {
        let forwardDistance = simd_dot(playerDelta, direction)
        let lateralDistance = abs(
            playerDelta.x * direction.y - playerDelta.y * direction.x
        )

        // Cars only yield to a player who is ahead and within their lane.
        // Nearby players on the pavement, behind a car, or in the opposite
        // lane no longer stop the whole traffic loop.
        guard lateralDistance < playerLaneHalfWidth,
              forwardDistance > -0.25,
              forwardDistance < playerYieldDistance else {
            return vehicle.topSpeed
        }

        let yieldFactor = min(
            max(
                (forwardDistance - playerStopDistance)
                    / (playerYieldDistance - playerStopDistance),
                0
            ),
            1
        )
        return vehicle.topSpeed * yieldFactor
    }

    private func forwardGap(
        for vehicleIndex: Int,
        pathDistances: [Float]
    ) -> Float? {
        let vehicle = vehicles[vehicleIndex]
        let loopLength = pathLength(vehicle.path)
        guard loopLength > 0 else { return nil }

        var closestGap: Float?
        for otherIndex in vehicles.indices where otherIndex != vehicleIndex {
            guard vehicles[otherIndex].path.name == vehicle.path.name else {
                continue
            }

            var gap = pathDistances[otherIndex] - pathDistances[vehicleIndex]
            if gap <= 0 { gap += loopLength }
            if closestGap == nil || gap < closestGap! {
                closestGap = gap
            }
        }
        return closestGap
    }

    private func distanceAlongPath(_ vehicle: Vehicle) -> Float {
        let points = vehicle.path.points
        var distance: Float = 0

        for segment in 0..<vehicle.segment {
            let next = (segment + 1) % points.count
            distance += simd_distance(points[segment], points[next])
        }

        let next = (vehicle.segment + 1) % points.count
        distance += simd_distance(points[vehicle.segment], points[next])
            * vehicle.progress
        return distance
    }

    private func pathLength(_ path: TrafficPathRecord) -> Float {
        let points = path.points
        return points.indices.reduce(0) { total, segment in
            let next = (segment + 1) % points.count
            return total + simd_distance(points[segment], points[next])
        }
    }

    func allowsPlayerMovement(
        from current: SIMD3<Float>,
        to target: SIMD3<Float>,
        radius: Float
    ) -> Bool {
        let minimumDistanceSquared = pow(radius + 1.05, 2)

        return !vehicles.contains { vehicle in
            let car = vehicle.node.simdWorldPosition
            let currentDelta = SIMD2<Float>(current.x - car.x, current.z - car.z)
            let targetDelta = SIMD2<Float>(target.x - car.x, target.z - car.z)
            let currentDistanceSquared = simd_length_squared(currentDelta)
            let targetDistanceSquared = simd_length_squared(targetDelta)

            guard targetDistanceSquared < minimumDistanceSquared else {
                return false
            }

            // If a car has already overlapped the player, permit only movement
            // that increases separation so the player can never be trapped.
            let isEscapingExistingOverlap =
                currentDistanceSquared < minimumDistanceSquared
                && targetDistanceSquared > currentDistanceSquared + 0.0001
            return !isEscapingExistingOverlap
        }
    }

    private func advance(_ vehicle: inout Vehicle, distance: Float) {
        var remaining = distance
        while remaining > 0 {
            let points = vehicle.path.points
            let next = (vehicle.segment + 1) % points.count
            let segmentLength = simd_distance(points[vehicle.segment], points[next])
            let available = segmentLength * (1 - vehicle.progress)

            if remaining < available {
                vehicle.progress += remaining / segmentLength
                remaining = 0
            } else {
                remaining -= available
                vehicle.segment = next
                vehicle.progress = 0
            }
        }
    }

    private func applyTransform(to vehicle: inout Vehicle) {
        let points = vehicle.path.points
        let next = (vehicle.segment + 1) % points.count
        let point = simd_mix(
            points[vehicle.segment],
            points[next],
            SIMD2<Float>(repeating: vehicle.progress)
        )
        let direction = simd_normalize(points[next] - points[vehicle.segment])

        vehicle.node.simdPosition = SIMD3<Float>(point.x, point.y, 0)
        var rotation = vehicle.node.simdEulerAngles
        rotation.z = atan2(direction.y, direction.x)
        vehicle.node.simdEulerAngles = rotation
    }

    private func segmentDirection(for vehicle: Vehicle) -> (
        blenderDirection: SIMD2<Float>,
        sceneDirection: SIMD2<Float>
    ) {
        let points = vehicle.path.points
        let next = (vehicle.segment + 1) % points.count
        let blender = simd_normalize(points[next] - points[vehicle.segment])
        return (blender, SIMD2<Float>(blender.x, -blender.y))
    }

    private static func closestPath(
        to point: SIMD2<Float>,
        paths: [TrafficPathRecord]
    ) -> (path: TrafficPathRecord, segment: Int, progress: Float)? {
        var best: (TrafficPathRecord, Int, Float, Float)?

        for path in paths {
            for segment in path.points.indices {
                let next = (segment + 1) % path.points.count
                let start = path.points[segment]
                let delta = path.points[next] - start
                let lengthSquared = simd_length_squared(delta)
                let progress = min(max(simd_dot(point - start, delta) / lengthSquared, 0), 1)
                let projected = start + delta * progress
                let distance = simd_distance(point, projected)
                if best == nil || distance < best!.3 {
                    best = (path, segment, progress, distance)
                }
            }
        }

        return best.map { ($0.0, $0.1, $0.2) }
    }
}

private extension SCNNode {
    func childNodes(passingTest test: (SCNNode) -> Bool) -> [SCNNode] {
        var matches: [SCNNode] = []
        enumerateChildNodes { node, _ in
            if test(node) { matches.append(node) }
        }
        return matches
    }
}

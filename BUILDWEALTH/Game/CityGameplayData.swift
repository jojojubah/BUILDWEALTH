import Foundation
import simd

struct CityInteractionManifest: Decodable {
    let buildings: [BuildingRecord]
    let doors: [DoorRecord]
}

struct BuildingRecord: Decodable {
    let buildingID: Int
    let rootEntity: String
    let boundsMin: [Float]
    let boundsMax: [Float]
    let interiorID: String

    enum CodingKeys: String, CodingKey {
        case buildingID = "building_id"
        case rootEntity = "root_entity"
        case boundsMin = "bounds_min"
        case boundsMax = "bounds_max"
        case interiorID = "interior_id"
    }

    var sceneBounds: WorldBounds {
        WorldBounds(
            minX: boundsMin[0],
            maxX: boundsMax[0],
            minZ: -boundsMax[1],
            maxZ: -boundsMin[1],
            height: boundsMax[2]
        )
    }
}

struct DoorRecord: Decodable {
    let doorID: Int
    let doorEntity: String
    let triggerEntity: String
    let buildingID: Int
    let interiorID: String
    let triggerCenter: [Float]
    let triggerSize: [Float]

    enum CodingKeys: String, CodingKey {
        case doorID = "door_id"
        case doorEntity = "door_entity"
        case triggerEntity = "trigger_entity"
        case buildingID = "building_id"
        case interiorID = "interior_id"
        case triggerCenter = "trigger_center"
        case triggerSize = "trigger_size"
    }

    var sceneTrigger: WorldBounds {
        let halfX = triggerSize[0] * 0.5
        let halfZ = triggerSize[1] * 0.5
        let centerX = triggerCenter[0]
        let centerZ = -triggerCenter[1]
        return WorldBounds(
            minX: centerX - halfX,
            maxX: centerX + halfX,
            minZ: centerZ - halfZ,
            maxZ: centerZ + halfZ,
            height: triggerCenter[2] + triggerSize[2] * 0.5
        )
    }
}

struct TrafficManifest: Decodable {
    let paths: [TrafficPathRecord]
    let vehicles: [TrafficVehicleRecord]
}

struct TrafficPathRecord: Decodable {
    let name: String
    let closedLoop: Bool
    let recommendedSpeed: Float
    let waypoints: [[Float]]

    enum CodingKeys: String, CodingKey {
        case name
        case closedLoop = "closed_loop"
        case recommendedSpeed = "recommended_speed_mps"
        case waypoints
    }

    var points: [SIMD2<Float>] {
        waypoints.map { SIMD2<Float>($0[0], $0[1]) }
    }
}

struct TrafficVehicleRecord: Decodable {
    let name: String
    let position: [Float]
    let heading: Float
    let maxSpeed: Float

    enum CodingKeys: String, CodingKey {
        case name, position
        case heading = "heading_radians"
        case maxSpeed = "max_speed_mps"
    }
}

struct WorldBounds {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    let height: Float

    func expanded(by amount: Float) -> WorldBounds {
        WorldBounds(
            minX: minX - amount,
            maxX: maxX + amount,
            minZ: minZ - amount,
            maxZ: maxZ + amount,
            height: height
        )
    }

    func contains(_ point: SIMD3<Float>) -> Bool {
        point.x >= minX && point.x <= maxX
            && point.z >= minZ && point.z <= maxZ
    }

    func segmentEntry(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Float? {
        let delta = end - start
        var near: Float = 0
        var far: Float = 1

        for (origin, direction, minimum, maximum) in [
            (start.x, delta.x, minX, maxX),
            (start.z, delta.z, minZ, maxZ),
        ] {
            if abs(direction) < 0.0001 {
                if origin < minimum || origin > maximum { return nil }
                continue
            }

            let first = (minimum - origin) / direction
            let second = (maximum - origin) / direction
            near = max(near, min(first, second))
            far = min(far, max(first, second))
            if near > far { return nil }
        }

        return near
    }
}

enum GameplayDataLoader {
    static func interactions() throws -> CityInteractionManifest {
        try load("FloatingCliffCity.interactions", extension: "json")
    }

    static func traffic() throws -> TrafficManifest {
        try load("FloatingCliffCity.traffic", extension: "json")
    }

    private static func load<T: Decodable>(_ name: String, extension ext: String) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

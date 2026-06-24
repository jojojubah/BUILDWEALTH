# BUILDWEALTH

Game-ready floating city assets for the BUILDWEALTH iOS and macOS game.

## Runtime asset

Add [`Assets/City/FloatingCliffCity.usdz`](Assets/City/FloatingCliffCity.usdz)
to the Xcode target and load it with RealityKit:

```swift
let city = try await Entity(named: "FloatingCliffCity", in: .main)
content.add(city)
```

The USDZ is:

- Y-up and authored in metres
- validated with Apple's `usdchecker`
- exported with materials, hierarchy, normals, and custom properties
- structured for RealityKit entity lookup

## Included gameplay data

`FloatingCliffCity.usdz` contains:

- 126 `BUILDING_###` visual roots
- 126 `DOOR_TRIGGER_###` trigger entities
- 126 `COLLIDER_BUILDING_###` static collision proxies
- a ground collider and optional city-edge colliders
- 28 `CAR_###` traffic roots and car collision proxies
- 8 `TRAFFIC_PATH_###` waypoint loops

The companion JSON files contain the same stable IDs in an easy-to-decode form:

- `FloatingCliffCity.interactions.json`
- `FloatingCliffCity.traffic.json`

## Runtime responsibilities

The asset provides geometry and metadata. The game should implement:

- collision events for `DOOR_TRIGGER_###`
- changing the matching door to its black active material
- presenting the matching `INTERIOR_###` with a SwiftUI full-screen cover
- raycasting from the camera to the player and fading obstructing
  `BUILDING_###` roots
- moving `CAR_###` roots along the traffic waypoints
- intersection rules, spawning, despawning, and wheel animation

## Authoring source

The editable Blender source is stored at:

`Source/Blender/FloatingCliffCity.blend`

Re-export after source changes and rerun:

```sh
usdchecker Assets/City/FloatingCliffCity.usdz
```


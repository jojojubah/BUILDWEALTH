# BUILDWEALTH

Game-ready floating city assets for the BUILDWEALTH iOS and macOS game.

## Run the game

Open `BUILDWEALTH.xcodeproj`, select the `BUILDWEALTH` scheme, and run on
macOS or an iOS simulator/device.

- macOS movement: WASD or arrow keys
- iOS movement: on-screen virtual stick
- The opening camera looks north-west across Central Park

## Player pipeline

The reusable Blender source is
`Assets/Characters/BUILDWEALTH_Player.blend`. It contains the named
`Happy Idle` and `Walking` actions plus relinked 4K skin textures.

To rebuild it and the two runtime clips:

```sh
/path/to/Blender --background --python Tools/build_character.py -- \
  /path/to/player.fbx /path/to/idle.fbx /path/to/walk.fbx \
  Assets/Characters/BUILDWEALTH_Player.blend
usdchecker Assets/Characters/PlayerIdle.usdz
usdchecker Assets/Characters/PlayerWalk.usdz
```

The app crossfades from `PlayerIdle.usdz` to `PlayerWalk.usdz` whenever the
player starts moving.

## Gameplay systems

The runtime reads both city manifests directly:

- building bounds provide player collision with wall sliding
- door trigger boxes blacken the matching door and open its interior screen
- returning from an interior requires leaving the doorway before retriggering
- all 28 cars follow the eight authored traffic loops
- vehicles accelerate, brake for traffic/player proximity, yield at crossings,
  rotate their wheels, and block the player
- buildings between the camera and player fade without disabling collision

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

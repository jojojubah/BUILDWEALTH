# RealityKit integration notes

## Door entry

Subscribe to collision-began events for entities named `DOOR_TRIGGER_###`.
Read the matching `interior_id` from the interaction manifest, turn the linked
door black, debounce the event, and set application state that presents the
interior with `fullScreenCover`.

The interior screen should be a separate scene or SwiftUI/RealityKit view. The
city USDZ deliberately does not embed 126 interiors.

## Camera occlusion

Raycast from the camera toward the player every frame or at a throttled rate.
Walk the hit entity's ancestors until a `BUILDING_###` root is found. Set that
root's `OpacityComponent` to zero over roughly 0.16 seconds. Restore the
previously blocked building to full opacity when it no longer obstructs the
view.

Only visual building roots should fade. Collision proxies remain separate so
the player cannot walk through a temporarily invisible building.

## Traffic

Move each `CAR_###` root along one of the closed `TRAFFIC_PATH_###` waypoint
loops. Runtime code owns speed, steering interpolation, intersection yielding,
spawn density, wheel rotation, and collision response.

Keep traffic simulation lightweight on iOS by updating distant vehicles less
frequently and disabling vehicles outside the active gameplay area.


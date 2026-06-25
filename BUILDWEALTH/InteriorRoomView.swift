import SceneKit
import SwiftUI

struct InteriorRoomView: View {
    let destination: InteriorDestination

    var body: some View {
        InteriorRoomSceneView(destination: destination)
            .ignoresSafeArea()
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.08),
                        .clear,
                        .black.opacity(0.32),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
    }
}

private struct InteriorPalette {
    let floor: PlatformColor
    let wall: PlatformColor
    let ceiling: PlatformColor
    let trim: PlatformColor

    static func palette(for destination: InteriorDestination) -> InteriorPalette {
        switch destination.id {
        case "INTERIOR_017":
            return InteriorPalette(
                floor: PlatformColor(red: 0.30, green: 0.32, blue: 0.36, alpha: 1),
                wall: PlatformColor(red: 0.82, green: 0.20, blue: 0.32, alpha: 1),
                ceiling: PlatformColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
                trim: PlatformColor(red: 1.0, green: 0.87, blue: 0.89, alpha: 1)
            )
        case "INTERIOR_071":
            return InteriorPalette(
                floor: PlatformColor(red: 0.30, green: 0.32, blue: 0.36, alpha: 1),
                wall: PlatformColor(red: 0.91, green: 0.92, blue: 0.93, alpha: 1),
                ceiling: PlatformColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
                trim: PlatformColor(red: 0.76, green: 0.79, blue: 0.83, alpha: 1)
            )
        case "INTERIOR_018":
            return InteriorPalette(
                floor: PlatformColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1),
                wall: PlatformColor(red: 0.18, green: 0.34, blue: 0.55, alpha: 1),
                ceiling: PlatformColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1),
                trim: PlatformColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 1)
            )
        case "INTERIOR_050":
            return InteriorPalette(
                floor: PlatformColor(red: 0.34, green: 0.29, blue: 0.23, alpha: 1),
                wall: PlatformColor(red: 0.86, green: 0.89, blue: 0.78, alpha: 1),
                ceiling: PlatformColor(red: 0.96, green: 0.97, blue: 0.94, alpha: 1),
                trim: PlatformColor(red: 0.25, green: 0.46, blue: 0.33, alpha: 1)
            )
        default:
            return InteriorPalette(
                floor: PlatformColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1),
                wall: PlatformColor(red: 0.44, green: 0.28, blue: 0.42, alpha: 1),
                ceiling: PlatformColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1),
                trim: PlatformColor(red: 0.88, green: 0.84, blue: 0.90, alpha: 1)
            )
        }
    }
}

#if os(macOS)
import AppKit
private typealias PlatformColor = NSColor

private struct InteriorRoomSceneView: NSViewRepresentable {
    let destination: InteriorDestination

    func makeNSView(context: Context) -> SCNView {
        makeRoomView(destination: destination)
    }

    func updateNSView(_ view: SCNView, context: Context) {
        configurePalette(in: view, destination: destination)
    }
}
#else
import UIKit
private typealias PlatformColor = UIColor

private struct InteriorRoomSceneView: UIViewRepresentable {
    let destination: InteriorDestination

    func makeUIView(context: Context) -> SCNView {
        makeRoomView(destination: destination)
    }

    func updateUIView(_ view: SCNView, context: Context) {
        configurePalette(in: view, destination: destination)
    }
}
#endif

private func makeRoomView(destination: InteriorDestination) -> SCNView {
    let view = SCNView()
    let scene = SCNScene(named: "ReusableInteriorRoom.usdz") ?? SCNScene()
    view.scene = scene
    view.backgroundColor = PlatformColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1)
    view.antialiasingMode = .multisampling4X
    view.rendersContinuously = false
    view.isPlaying = false

    let camera = SCNCamera()
    camera.fieldOfView = 58
    camera.wantsHDR = true
    camera.wantsExposureAdaptation = true
    camera.exposureOffset = 0.35
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, -9.2, 2.7)
    cameraNode.look(
        at: SCNVector3(0, 3.2, 1.55),
        up: SCNVector3(0, 0, 1),
        localFront: SCNVector3(0, 0, -1)
    )
    scene.rootNode.addChildNode(cameraNode)
    view.pointOfView = cameraNode

    let key = SCNLight()
    key.type = .omni
    key.intensity = 1_050
    key.temperature = 4_900
    key.attenuationStartDistance = 3
    key.attenuationEndDistance = 16
    let keyNode = SCNNode()
    keyNode.light = key
    keyNode.position = SCNVector3(-2.4, -1.2, 3.0)
    scene.rootNode.addChildNode(keyNode)

    let fill = SCNLight()
    fill.type = .ambient
    fill.intensity = 520
    fill.color = PlatformColor(red: 0.52, green: 0.62, blue: 0.82, alpha: 1)
    let fillNode = SCNNode()
    fillNode.light = fill
    scene.rootNode.addChildNode(fillNode)

    configurePalette(in: view, destination: destination)
    return view
}

private func configurePalette(in view: SCNView, destination: InteriorDestination) {
    guard let root = view.scene?.rootNode else { return }
    let palette = InteriorPalette.palette(for: destination)

    root.enumerateChildNodes { node, _ in
        guard let name = node.name else { return }
        let color: PlatformColor?
        if name.hasPrefix("ROOM_FLOOR") {
            color = palette.floor
        } else if name.hasPrefix("ROOM_WALL") {
            color = palette.wall
        } else if name.hasPrefix("ROOM_CEILING") {
            color = palette.ceiling
        } else if name.hasPrefix("ROOM_TRIM") || name == "CEILING_PANEL" {
            color = palette.trim
        } else {
            color = nil
        }

        if let color {
            node.enumerateChildNodes { meshNode, _ in
                guard let geometry = meshNode.geometry else { return }
                geometry.materials = geometry.materials.map { original in
                    let material = original.copy() as! SCNMaterial
                    material.diffuse.contents = color
                    return material
                }
            }
        }
    }
}

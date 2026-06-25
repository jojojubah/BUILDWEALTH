import SceneKit
import SwiftUI

#if os(macOS)
import AppKit

struct GameView: NSViewRepresentable {
    let controller: GameSceneController

    func makeNSView(context: Context) -> GameSCNView {
        makeView()
    }

    func updateNSView(_ view: GameSCNView, context: Context) {}

    private func makeView() -> GameSCNView {
        let view = GameSCNView()
        configure(view)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    private func configure(_ view: GameSCNView) {
        view.controller = controller
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.delegate = controller
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.backgroundColor = .black
    }
}

final class GameSCNView: SCNView {
    weak var controller: GameSceneController?
    private var heldKeys = Set<String>()

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if let direction = direction(for: event.keyCode) {
            heldKeys.insert(direction)
            publishInput()
            return
        }
        if let characters = event.charactersIgnoringModifiers?.lowercased() {
            heldKeys.insert(characters)
            publishInput()
        }
    }

    override func keyUp(with event: NSEvent) {
        if let direction = direction(for: event.keyCode) {
            heldKeys.remove(direction)
            publishInput()
            return
        }
        if let characters = event.charactersIgnoringModifiers?.lowercased() {
            heldKeys.remove(characters)
            publishInput()
        }
    }

    private func publishInput() {
        let x = axis(positive: ["d", "right"], negative: ["a", "left"])
        let y = axis(positive: ["w", "up"], negative: ["s", "down"])
        controller?.setInput(SIMD2<Float>(x, y))
    }

    private func direction(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return nil
        }
    }

    private func axis(positive: Set<String>, negative: Set<String>) -> Float {
        let positiveValue: Float = heldKeys.isDisjoint(with: positive) ? 0 : 1
        let negativeValue: Float = heldKeys.isDisjoint(with: negative) ? 0 : 1
        return positiveValue - negativeValue
    }
}
#else
import UIKit

struct GameView: UIViewRepresentable {
    let controller: GameSceneController

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.delegate = controller
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}
}
#endif

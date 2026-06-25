import SwiftUI

struct VirtualStick: View {
    let onChange: (SIMD2<Float>) -> Void
    @State private var knob = CGSize.zero

    private let radius: CGFloat = 54

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.28))
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

            Circle()
                .fill(.white.opacity(0.22))
                .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                .frame(width: 48, height: 48)
                .offset(knob)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let raw = CGVector(
                        dx: value.location.x - radius,
                        dy: value.location.y - radius
                    )
                    let length = max(sqrt(raw.dx * raw.dx + raw.dy * raw.dy), 1)
                    let clamped = min(length, radius)
                    knob = CGSize(
                        width: raw.dx / length * clamped,
                        height: raw.dy / length * clamped
                    )
                    onChange(SIMD2<Float>(
                        Float(knob.width / radius),
                        Float(-knob.height / radius)
                    ))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        knob = .zero
                    }
                    onChange(.zero)
                }
        )
    }
}

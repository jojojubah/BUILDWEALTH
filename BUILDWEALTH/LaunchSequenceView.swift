import SwiftUI

enum LaunchPhase: Int {
    case logo
    case studio
    case title
    case game
}

struct LaunchSequenceView: View {
    let phase: LaunchPhase

    var body: some View {
        ZStack {
            Color(red: 0.008, green: 0.012, blue: 0.022)
                .ignoresSafeArea()

            if phase == .logo {
                Image("VibeNodeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 300)
                    .padding(48)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else if phase == .studio {
                VStack(spacing: -4) {
                    Text("Vibe Node")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .tracking(-2.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.38, blue: 0.82),
                                    Color(red: 0.35, green: 0.67, blue: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Games")
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .tracking(9)
                        .foregroundStyle(Color(red: 0.92, green: 0.18, blue: 0.22))
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else if phase == .title {
                VStack(spacing: -8) {
                    Text("BUILD")
                        .foregroundStyle(.white)
                    Text("WEALTH")
                        .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))
                }
                .font(.system(size: 76, weight: .black, design: .rounded))
                .tracking(-3)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

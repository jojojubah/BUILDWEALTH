import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameSceneController()
    @State private var launchPhase: LaunchPhase = .logo
    @State private var showsWelcome = false
    @State private var showsPlayerStats = false

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.02, blue: 0.035)
                .ignoresSafeArea()

            GameView(controller: game)
                .ignoresSafeArea()

            if showsPlayerStats {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showsPlayerStats = false
                        }
                    }
                    .zIndex(1)
            }

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        brand
                        clock
                    }
                    Spacer()
                    HStack(alignment: .top, spacing: 10) {
                        PlayerStatsMenu(isExpanded: $showsPlayerStats)
                        wallet
                    }
                }
                Spacer()

                #if os(iOS)
                HStack {
                    Spacer()
                    VirtualStick { vector in
                        game.setInput(vector)
                    }
                    Spacer()
                }
                #else
                HStack {
                    Text("MOVE  WASD / ARROW KEYS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.65))
                #endif
            }
            .padding(24)
            .zIndex(2)

            if let destination = game.activeInterior {
                InteriorView(destination: destination) {
                    game.dismissInterior()
                }
                .transition(.opacity)
                .zIndex(10)
            }

            if showsWelcome {
                WelcomeMessageView {
                    showsWelcome = false
                }
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(15)
            }

            if launchPhase != .game {
                LaunchSequenceView(phase: launchPhase)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: game.activeInterior)
        .animation(.easeInOut(duration: 0.25), value: showsWelcome)
        .animation(.easeInOut(duration: 0.55), value: launchPhase)
        .task {
            guard launchPhase == .logo else { return }
            try? await Task.sleep(for: .seconds(1.7))
            launchPhase = .studio
            try? await Task.sleep(for: .seconds(1.7))
            launchPhase = .title
            try? await Task.sleep(for: .seconds(1.7))
            launchPhase = .game
            try? await Task.sleep(for: .milliseconds(450))
            showsWelcome = true
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BUILD")
                .foregroundStyle(.white)
            Text("WEALTH")
                .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))
        }
        .font(.system(size: 22, weight: .black, design: .rounded))
        .tracking(-0.8)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private var clock: some View {
        HStack(spacing: 7) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.4, green: 0.72, blue: 1))

            Text("06:00")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var wallet: some View {
        HStack(spacing: 8) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.42, green: 0.75, blue: 1))

            Text("$0")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text("💰")
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.62), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

}

struct PlayerStatsMenu: View {
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))
                    .frame(width: 38, height: 34)
                    .background(.black.opacity(0.62), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Close player stats" : "Show player stats")

            if isExpanded {
                VStack(spacing: 0) {
                    statRow(
                        symbol: "heart.circle.fill",
                        title: "Karma",
                        value: "0",
                        color: Color(red: 1, green: 0.72, blue: 0.2)
                    )

                    Divider()
                        .overlay(.white.opacity(0.12))

                    statRow(
                        symbol: "brain.head.profile.fill",
                        title: "Intelligence",
                        value: "0",
                        color: Color(red: 0.42, green: 0.75, blue: 1)
                    )
                }
                .frame(width: 190)
                .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    private func statRow(
        symbol: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}

private struct WelcomeMessageView: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("WELCOME TO HODL CITY")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))
                    .multilineTextAlignment(.center)

                Text("Build as much wealth as you can, explore the city and find ways to make money.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button("Start Exploring", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.16, green: 0.43, blue: 0.88))
                    .controlSize(.large)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .frame(maxWidth: 500)
            .background(
                Color(red: 0.035, green: 0.05, blue: 0.08),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
            .padding(24)
        }
    }
}

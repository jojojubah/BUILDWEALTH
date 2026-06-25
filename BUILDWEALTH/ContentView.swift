import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameSceneController()
    @State private var launchPhase: LaunchPhase = .logo
    @State private var showsWelcome = false

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.02, blue: 0.035)
                .ignoresSafeArea()

            GameView(controller: game)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        brand
                        clock
                    }
                    Spacer()
                    wallet
                }
                Spacer()

                #if os(iOS)
                HStack(alignment: .bottom) {
                    VirtualStick { vector in
                        game.setInput(vector)
                    }
                    Spacer()
                    actionButton
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

    private var actionButton: some View {
        Button(action: game.interact) {
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 22, weight: .bold))
                .frame(width: 62, height: 62)
                .background(Color.white.opacity(0.14), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

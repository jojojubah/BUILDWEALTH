import SwiftUI

struct InteriorDestination: Identifiable, Equatable {
    let id: String
    let buildingID: Int
}

struct InteriorView: View {
    let destination: InteriorDestination
    let dismiss: () -> Void

    private var isHome: Bool {
        destination.id == "INTERIOR_018"
    }

    private var isBurgerShop: Bool {
        destination.id == "INTERIOR_017"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.055, blue: 0.08),
                    Color(red: 0.008, green: 0.012, blue: 0.022),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text(
                        isHome
                            ? "BUILDWEALTH RESIDENCE"
                            : isBurgerShop ? "HODL CITY DINING" : "BUILDING \(destination.buildingID)"
                    )
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))

                    Text(
                        isHome
                            ? "HOME"
                            : isBurgerShop
                                ? "BURGER SHOP"
                                : destination.id.replacingOccurrences(of: "_", with: " ")
                    )
                        .font(.system(size: 34, weight: .black, design: .rounded))

                    Text(
                        isHome
                            ? "Welcome home"
                            : isBurgerShop
                                ? "Burgers, bites and business"
                                : "Interior scene ready for content"
                    )
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 36)

                Spacer()

                Button("Return to City", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.45, green: 0.78, blue: 0.12))
                    .controlSize(.large)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
    }
}

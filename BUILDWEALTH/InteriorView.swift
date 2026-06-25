import SwiftUI

struct InteriorDestination: Identifiable, Equatable {
    let id: String
    let buildingID: Int
}

struct InteriorView: View {
    let destination: InteriorDestination
    let dismiss: () -> Void
    @State private var showsPlayerStats = false

    private var isHome: Bool {
        destination.id == "INTERIOR_018"
    }

    private var isBank: Bool {
        destination.id == "INTERIOR_071"
    }

    private var isBurgerShop: Bool {
        destination.id == "INTERIOR_017"
    }

    private var isSchool: Bool {
        destination.id == "INTERIOR_050"
    }

    var body: some View {
        ZStack {
            InteriorRoomView(destination: destination)

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

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text(
                        isHome
                            ? "BUILDWEALTH RESIDENCE"
                            : isBank
                                ? "HODL CITY FINANCIAL"
                                : isBurgerShop
                                    ? "HODL CITY DINING"
                                : isSchool ? "HODL CITY EDUCATION" : "BUILDING \(destination.buildingID)"
                    )
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color(red: 0.65, green: 1, blue: 0.22))

                    Text(
                        isHome
                            ? "HOME"
                            : isBank
                                ? "BANK"
                                : isBurgerShop
                                    ? "BURGER SHOP"
                                : isSchool
                                    ? "SCHOOL"
                                : destination.id.replacingOccurrences(of: "_", with: " ")
                    )
                        .font(.system(size: 34, weight: .black, design: .rounded))

                    Text(
                        isHome
                            ? "Welcome home"
                            : isBank
                                ? "Save, invest and build wealth"
                                : isBurgerShop
                                    ? "Burgers, bites and business"
                                : isSchool
                                    ? "Learn skills and invest in yourself"
                                : "Interior scene ready for content"
                    )
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 36)

                HStack(alignment: .top) {
                    interiorClock

                    Spacer(minLength: 16)

                    HStack(alignment: .top, spacing: 10) {
                        PlayerStatsMenu(isExpanded: $showsPlayerStats)
                        interiorWallet
                    }
                }
                .padding(.top, 18)

                Spacer()

                Button("Return to City", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.45, green: 0.78, blue: 0.12))
                    .controlSize(.large)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(2)

            if isHome {
                HStack {
                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 20, weight: .semibold))

                            Text("Sleep")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .background(.black.opacity(0.72), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    Color(red: 1, green: 0.82, blue: 0.12).opacity(0.75),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sleep")

                    Spacer()
                }
                .padding(.leading, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var interiorClock: some View {
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

    private var interiorWallet: some View {
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

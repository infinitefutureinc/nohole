import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var glow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                appBadge
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("NoGlasshole")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-0.8)

                    Text("The privacy layer for smart glasses.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("Detect nearby Meta Ray-Bans.\nBlur faces in your footage.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 40)

            primaryButton
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            Spacer().frame(height: 24)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65).delay(0.1)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var appBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AccentGreen"),
                            Color("AccentGreen").opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .shadow(color: Color("AccentGreen").opacity(glow ? 0.6 : 0.3), radius: glow ? 30 : 18)

            Image(systemName: "eye.slash.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.black)
        }
    }

    private var primaryButton: some View {
        Button(action: onContinue) {
            Text("Get started")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color("AccentGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
        .preferredColorScheme(.dark)
}

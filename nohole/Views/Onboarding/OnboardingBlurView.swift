import SwiftUI

struct OnboardingBlurView: View {
    let onContinue: () -> Void

    @State private var isBlurred: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // Stylized "photo" frame with three faces
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 280, height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .inset(by: 0.5)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                HStack(spacing: 18) {
                    faceCircle(size: 70, blurOffset: -2)
                    faceCircle(size: 90, blurOffset: 0)
                    faceCircle(size: 70, blurOffset: 2)
                }

                // PRIVACY ON tag
                if isBlurred {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color("AccentGreen"))
                            .frame(width: 6, height: 6)
                        Text("PRIVACY ON")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color("AccentGreen"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .offset(x: 90, y: -110)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 320)

            Spacer()

            VStack(spacing: 16) {
                Text("Post With\nPrivacy On.")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Every face auto-blurred in under a second.\nOn your device. Always.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)

            primaryButton

            Spacer().frame(height: 24)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    isBlurred = true
                }
            }
        }
    }

    private func faceCircle(size: CGFloat, blurOffset: CGFloat) -> some View {
        ZStack {
            // Sharp face
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.95, green: 0.78, blue: 0.62),
                             Color(red: 0.85, green: 0.65, blue: 0.50)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size, height: size)
                .overlay(
                    VStack(spacing: size * 0.12) {
                        HStack(spacing: size * 0.18) {
                            Circle().fill(.black.opacity(0.7)).frame(width: size * 0.10, height: size * 0.10)
                            Circle().fill(.black.opacity(0.7)).frame(width: size * 0.10, height: size * 0.10)
                        }
                        Capsule().fill(.black.opacity(0.5)).frame(width: size * 0.30, height: size * 0.04)
                    }
                    .offset(y: -size * 0.05)
                )
                .opacity(isBlurred ? 0 : 1)
                .blur(radius: isBlurred ? 18 : 0)

            // Blurred replacement (a soft pixelated/blurred disc)
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.92, green: 0.75, blue: 0.60),
                             Color(red: 0.78, green: 0.60, blue: 0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size, height: size)
                .blur(radius: 14)
                .opacity(isBlurred ? 1 : 0)
        }
        .offset(y: blurOffset)
    }

    private var primaryButton: some View {
        Button(action: onContinue) {
            Text("Continue")
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
    OnboardingBlurView(onContinue: {})
        .preferredColorScheme(.dark)
}

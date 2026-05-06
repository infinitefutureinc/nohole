import SwiftUI
import Photos

struct OnboardingPhotosView: View {
    let onContinue: () -> Void

    @State private var hasRequested: Bool = false
    @State private var float: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                photoStack(offset: -38, rotation: -8, depth: 0)
                photoStack(offset: 0, rotation: 0, depth: 1)
                photoStack(offset: 38, rotation: 8, depth: 0)

                // Lock chip
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("ON DEVICE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                }
                .foregroundStyle(Color("AccentGreen"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color("AccentGreen").opacity(0.4), lineWidth: 1)
                )
                .offset(y: 100)
                .zIndex(10)
            }
            .frame(height: 280)
            .offset(y: float ? -4 : 4)
            .animation(
                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: float
            )

            Spacer()

            VStack(spacing: 16) {
                Text("Faces blurred\non your device.")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("We need photo access to blur faces.\nWe can't see your photos. Nothing is uploaded.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)

            primaryButton

            Spacer().frame(height: 24)
        }
        .onAppear { float = true }
    }

    private func photoStack(offset: CGFloat, rotation: Double, depth: Int) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(LinearGradient(
                colors: [Color(.systemGray4), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 150, height: 200)
            .overlay(
                Circle()
                    .fill(Color(red: 0.88, green: 0.72, blue: 0.55))
                    .frame(width: 64, height: 64)
                    .blur(radius: 12)
                    .offset(y: -10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .inset(by: 0.5)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
            .offset(x: offset)
            .zIndex(Double(depth))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private var primaryButton: some View {
        Button {
            hasRequested = true
            Task {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                onContinue()
            }
        } label: {
            Text(hasRequested ? "Waiting…" : "Enable Photos")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color("AccentGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
        .disabled(hasRequested)
    }
}

#Preview {
    OnboardingPhotosView(onContinue: {})
        .preferredColorScheme(.dark)
}

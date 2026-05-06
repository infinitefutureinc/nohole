import SwiftUI

struct OnboardingDetectView: View {
    let onContinue: () -> Void

    @State private var isScanning: Bool = false
    @State private var hasDetection: Bool = false
    @State private var showCard: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RadarPulseView(isScanning: isScanning, hasDetection: hasDetection)

                if showCard {
                    detectionCard
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .opacity
                        ))
                        .offset(y: 140)
                }
            }
            .frame(height: 320)

            Spacer()

            VStack(spacing: 16) {
                Text("Stay Aware.\nStay You.")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Get pinged the moment Meta Ray-Bans\nare recording nearby.")
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
            isScanning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                hasDetection = true
                withAnimation(.spring(duration: 0.5)) {
                    showCard = true
                }
            }
        }
    }

    private var detectionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "eyeglasses")
                .font(.title2)
                .foregroundStyle(Color("AccentGreen"))
                .frame(width: 40, height: 40)
                .background(Color("AccentGreen").opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Meta Ray-Ban")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("just now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(Color("AccentGreen"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 280)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .inset(by: 0.5)
                .stroke(Color("AccentGreen").opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color("AccentGreen").opacity(0.2), radius: 12, y: 4)
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
    OnboardingDetectView(onContinue: {})
        .preferredColorScheme(.dark)
}

import SwiftUI
import StoreKit

struct OnboardingRatingView: View {
    let onContinue: () -> Void

    @Environment(\.requestReview) private var requestReview

    @State private var starsAppeared: [Bool] = Array(repeating: false, count: 5)
    @State private var pulse: Bool = false
    @State private var labelAppeared: Bool = false
    @State private var labelFloat: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // "Rate 5 Stars" label above the stars with animation
                Text("Rate 5 Stars")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color("AccentGreen"))
                    .opacity(labelAppeared ? 1 : 0)
                    .offset(y: labelAppeared ? (labelFloat ? -4 : 4) : 12)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: labelFloat)

                stars
            }
            .frame(height: 200)

            Spacer()

            VStack(spacing: 16) {
                Text("Help more people\nspot smart glasses.")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("NoGlasshole spreads through the App Store.\nA 5-star rating means more people get protected — for free.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)

            Button(action: onContinue) {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("AccentGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)
        }
        .onAppear {
            animateStars()
            // Show the "Rate 5 Stars" label after stars finish animating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.5)) {
                    labelAppeared = true
                }
                // Start the gentle float after it appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    labelFloat = true
                }
            }
            // Auto-present the App Store rating dialog after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                requestReview()
            }
        }
    }

    private var stars: some View {
        HStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color("AccentGreen"))
                    .shadow(color: Color("AccentGreen").opacity(pulse ? 0.6 : 0.25), radius: pulse ? 18 : 8)
                    .scaleEffect(starsAppeared[i] ? 1 : 0.4)
                    .opacity(starsAppeared[i] ? 1 : 0)
                    .rotationEffect(.degrees(starsAppeared[i] ? 0 : -25))
            }
        }
    }

    private func animateStars() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                withAnimation(.spring(duration: 0.55, bounce: 0.45)) {
                    starsAppeared[i] = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    OnboardingRatingView(onContinue: {})
        .preferredColorScheme(.dark)
}

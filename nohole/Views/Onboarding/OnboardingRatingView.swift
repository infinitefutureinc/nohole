import SwiftUI
import StoreKit

struct OnboardingRatingView: View {
    let onContinue: () -> Void

    @Environment(\.requestReview) private var requestReview

    @State private var starsAppeared: [Bool] = Array(repeating: false, count: 5)
    @State private var pulse: Bool = false
    @State private var hasRated: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            stars
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

            VStack(spacing: 12) {
                Button {
                    hasRated = true
                    requestReview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(hasRated ? "Thanks for rating" : "Rate 5 Stars")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("AccentGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Button(action: onContinue) {
                    Text(hasRated ? "Continue" : "Next")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 16)
        }
        .onAppear { animateStars() }
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

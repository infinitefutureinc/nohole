import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var currentStep: Int = 0
    @State private var advanceTrigger: Int = 0

    private let totalSteps = 7

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                Group {
                    switch currentStep {
                    case 0:
                        OnboardingWelcomeView(onContinue: advance)
                    case 1:
                        OnboardingHookView(onContinue: advance)
                    case 2:
                        OnboardingDetectView(onContinue: advance)
                    case 3:
                        OnboardingBlurView(onContinue: advance)
                    case 4:
                        OnboardingBluetoothView(onContinue: advance)
                    case 5:
                        OnboardingPhotosView(onContinue: advance)
                    default:
                        OnboardingRatingView(onContinue: complete)
                    }
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: advanceTrigger)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Color("AccentGreen") : Color(.systemGray5).opacity(0.4))
                    .frame(width: i == currentStep ? 28 : 8, height: 6)
                    .animation(.spring(duration: 0.35), value: currentStep)
            }
        }
    }

    private func advance() {
        advanceTrigger += 1
        guard currentStep < totalSteps - 1 else {
            complete()
            return
        }
        withAnimation(.spring(duration: 0.45)) {
            currentStep += 1
        }
    }

    private func complete() {
        advanceTrigger += 1
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
}

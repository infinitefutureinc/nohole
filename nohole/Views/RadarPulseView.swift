import SwiftUI

struct RadarPulseView: View {
    let isScanning: Bool
    let hasDetection: Bool

    @State private var pulse0: CGFloat = 0.3
    @State private var pulse1: CGFloat = 0.3
    @State private var pulse2: CGFloat = 0.3
    @State private var opacity0: CGFloat = 0.6
    @State private var opacity1: CGFloat = 0.6
    @State private var opacity2: CGFloat = 0.6
    @State private var glowRadius: CGFloat = 10
    @State private var detectionFlash: Bool = false

    private let accentGreen = Color("AccentGreen")

    var body: some View {
        ZStack {
            // Pulse rings
            if isScanning {
                pulseRing(scale: $pulse0, opacity: $opacity0, delay: 0)
                pulseRing(scale: $pulse1, opacity: $opacity1, delay: 0.7)
                pulseRing(scale: $pulse2, opacity: $opacity2, delay: 1.4)
            } else {
                // Static rings when not scanning
                Circle()
                    .stroke(Color(.systemGray4).opacity(0.3), lineWidth: 1)
                    .frame(width: 160, height: 160)
                Circle()
                    .stroke(Color(.systemGray4).opacity(0.2), lineWidth: 1)
                    .frame(width: 220, height: 220)
            }

            // Detection flash ring
            if detectionFlash {
                Circle()
                    .stroke(accentGreen, lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(2.5)
                    .opacity(0)
            }

            // Center icon
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(isScanning ? 0.15 : 0.08))
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(accentGreen.opacity(isScanning ? 0.8 : 0.3), lineWidth: 2)
                    .frame(width: 88, height: 88)

                Image(systemName: "eyeglasses")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(isScanning ? accentGreen : Color(.systemGray2))
            }
            .shadow(color: isScanning ? accentGreen.opacity(0.5) : .clear, radius: glowRadius)
        }
        .frame(width: 260, height: 260)
        .onChange(of: isScanning) { _, scanning in
            if scanning {
                startPulseAnimations()
                startGlowAnimation()
            } else {
                resetAnimations()
            }
        }
        .onChange(of: hasDetection) { _, detected in
            if detected {
                triggerDetectionFlash()
            }
        }
        .onAppear {
            if isScanning {
                startPulseAnimations()
                startGlowAnimation()
            }
        }
    }

    private func pulseRing(scale: Binding<CGFloat>, opacity: Binding<CGFloat>, delay: Double) -> some View {
        Circle()
            .stroke(accentGreen, lineWidth: 2)
            .frame(width: 100, height: 100)
            .scaleEffect(scale.wrappedValue)
            .opacity(opacity.wrappedValue)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animateRing(scale: scale, opacity: opacity)
                }
            }
    }

    private func animateRing(scale: Binding<CGFloat>, opacity: Binding<CGFloat>) {
        scale.wrappedValue = 0.3
        opacity.wrappedValue = 0.6

        withAnimation(.easeOut(duration: 2.1).repeatForever(autoreverses: false)) {
            scale.wrappedValue = 2.8
            opacity.wrappedValue = 0
        }
    }

    private func startPulseAnimations() {
        animateRing(scale: $pulse0, opacity: $opacity0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            animateRing(scale: $pulse1, opacity: $opacity1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            animateRing(scale: $pulse2, opacity: $opacity2)
        }
    }

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowRadius = 25
        }
    }

    private func resetAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulse0 = 0.3
            pulse1 = 0.3
            pulse2 = 0.3
            opacity0 = 0
            opacity1 = 0
            opacity2 = 0
            glowRadius = 10
        }
    }

    private func triggerDetectionFlash() {
        detectionFlash = false
        withAnimation(.easeOut(duration: 0.6)) {
            detectionFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            detectionFlash = false
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        RadarPulseView(isScanning: true, hasDetection: false)
        RadarPulseView(isScanning: false, hasDetection: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .preferredColorScheme(.dark)
}

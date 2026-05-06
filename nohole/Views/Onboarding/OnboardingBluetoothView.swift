import SwiftUI
import CoreBluetooth

struct OnboardingBluetoothView: View {
    let onContinue: () -> Void

    @State private var scanner: BLEScanner?
    @State private var hasRequested: Bool = false
    @State private var observedState: CBManagerState = .unknown
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color("AccentGreen").opacity(0.4), lineWidth: 1.5)
                        .frame(width: 100 + CGFloat(i) * 60, height: 100 + CGFloat(i) * 60)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 0.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: pulse
                        )
                }

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color("AccentGreen"))
            }
            .frame(height: 280)

            Spacer()

            VStack(spacing: 16) {
                Text("We listen.\nWe never broadcast.")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Bluetooth is how we spot Meta Ray-Bans nearby.\nZero network calls. 100% on-device.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)

            primaryButton

            Spacer().frame(height: 24)
        }
        .onAppear { pulse = true }
        .onChange(of: observedState) { _, newState in
            if hasRequested && newState != .unknown && newState != .resetting {
                scanner?.stopScanning()
                onContinue()
            }
        }
    }

    private var primaryButton: some View {
        Button {
            hasRequested = true
            let s = BLEScanner()
            scanner = s
            s.startScanning()
            // Poll the observable state via a brief Task — onChange picks up the change.
            Task {
                for _ in 0..<60 {
                    observedState = s.bluetoothState
                    if observedState != .unknown && observedState != .resetting { break }
                    try? await Task.sleep(for: .milliseconds(150))
                }
                // Fallback: advance even if state never resolves (e.g. simulator)
                if observedState == .unknown {
                    onContinue()
                }
            }
        } label: {
            Text(hasRequested ? "Waiting…" : "Enable Bluetooth")
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
    OnboardingBluetoothView(onContinue: {})
        .preferredColorScheme(.dark)
}

import SwiftUI

struct OnboardingHookView: View {
    let onContinue: () -> Void

    private let columns = 5
    private let rows = 4
    private var totalCells: Int { columns * rows }

    @State private var recordingIndices: Set<Int> = []
    @State private var dotPulse: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            glassesGrid
                .frame(height: 280)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)

            Spacer()

            VStack(spacing: 16) {
                Text("Smile.\nYou're on camera.")
                    .font(.system(size: 38, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("20 million smart glasses look like ordinary glasses.\nThe cameras are invisible. The footage isn't.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)

            primaryButton

            Spacer().frame(height: 24)
        }
        .background(
            RadialGradient(
                colors: [Color.red.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)
        )
        .onAppear {
            withAnimation(.spring(duration: 0.55).delay(0.1)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                dotPulse = true
            }
            cycleRecordingCells()
        }
    }

    private var glassesGrid: some View {
        VStack(spacing: 18) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { col in
                        glassesCell(index: row * columns + col)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func glassesCell(index: Int) -> some View {
        let isRecording = recordingIndices.contains(index)
        return ZStack {
            Image(systemName: "eyeglasses")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(isRecording ? Color.red : Color(white: 0.32))
                .animation(.easeInOut(duration: 0.6), value: isRecording)

            if isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                            .scaleEffect(dotPulse ? 2.6 : 1.0)
                            .opacity(dotPulse ? 0 : 1)
                    )
                    .offset(x: 18, y: -10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 36)
    }

    private func cycleRecordingCells() {
        Task {
            // Initial seed
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeInOut(duration: 0.5)) {
                recordingIndices = pickRandom(count: 3)
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1300))
                withAnimation(.easeInOut(duration: 0.6)) {
                    recordingIndices = pickRandom(count: Int.random(in: 2...4))
                }
            }
        }
    }

    private func pickRandom(count: Int) -> Set<Int> {
        var picks: Set<Int> = []
        while picks.count < count {
            picks.insert(Int.random(in: 0..<totalCells))
        }
        return picks
    }

    private var primaryButton: some View {
        Button(action: onContinue) {
            Text("Take it back")
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
    OnboardingHookView(onContinue: {})
        .preferredColorScheme(.dark)
}

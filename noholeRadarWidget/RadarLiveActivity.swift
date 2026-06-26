import ActivityKit
import WidgetKit
import SwiftUI

private let accentGreen = Color("AccentGreen")

// MARK: - Widget

struct RadarLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadarActivityAttributes.self) { ctx in
            LockScreenView(state: ctx.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(accentGreen)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("NOGLASSHOLE", systemImage: "eyeglasses")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accentGreen)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusDot(state: ctx.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    CenterContent(state: ctx.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BottomBar(state: ctx.state)
                }
            } compactLeading: {
                Image(systemName: "eyeglasses")
                    .foregroundStyle(ctx.state.detectedGlassesCount > 0 ? .red : accentGreen)
            } compactTrailing: {
                Text("\(ctx.state.detectedGlassesCount)")
                    .monospacedDigit()
                    .fontWeight(.bold)
                    .foregroundStyle(ctx.state.detectedGlassesCount > 0 ? .red : accentGreen)
            } minimal: {
                Image(systemName: "eyeglasses")
                    .font(.caption)
                    .foregroundStyle(ctx.state.detectedGlassesCount > 0 ? .red : accentGreen)
            }
            .keylineTint(accentGreen)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let state: RadarActivityAttributes.ContentState
    private var alert: Bool { state.detectedGlassesCount > 0 }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("NOGLASSHOLE", systemImage: "eyeglasses")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))

                Text(headline)
                    .font(.headline)
                    .foregroundStyle(alert ? .red : .white)

                InfoLine(state: state)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)

            if alert {
                Text("\(state.detectedGlassesCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var headline: String {
        switch state.detectedGlassesCount {
        case 0: "All clear"
        case 1: "1 glasshole nearby"
        default: "\(state.detectedGlassesCount) glassholes nearby"
        }
    }
}

// MARK: - Shared Components

private struct StatusDot: View {
    let state: RadarActivityAttributes.ContentState
    private var alert: Bool { state.detectedGlassesCount > 0 }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(alert ? .red : accentGreen)
                .frame(width: 6, height: 6)
            Text("SCANNING")
                .font(.caption2.weight(.bold))
                .foregroundStyle(alert ? .red : accentGreen)
        }
    }
}

private struct CenterContent: View {
    let state: RadarActivityAttributes.ContentState
    private var alert: Bool { state.detectedGlassesCount > 0 }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(state.detectedGlassesCount)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(alert ? .red : accentGreen)
            Text(alert ? "DETECTED" : "ALL CLEAR")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct InfoLine: View {
    let state: RadarActivityAttributes.ContentState
    private var alert: Bool { state.detectedGlassesCount > 0 }

    var body: some View {
        if alert, let lastSeen = state.lastDetectionAt {
            Text("Detected \(Text(lastSeen, style: .relative)) ago")
        } else {
            Text("Scanning\u{2026}")
        }
    }
}

private struct BottomBar: View {
    let state: RadarActivityAttributes.ContentState

    var body: some View {
        InfoLine(state: state)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

extension RadarActivityAttributes {
    fileprivate static var preview: RadarActivityAttributes {
        RadarActivityAttributes()
    }
}

extension RadarActivityAttributes.ContentState {
    fileprivate static var allClear: RadarActivityAttributes.ContentState {
        .init(detectedGlassesCount: 0,
              lastDetectionAt: nil,
              nearbyDeviceCount: 5)
    }

    fileprivate static var detected: RadarActivityAttributes.ContentState {
        .init(detectedGlassesCount: 1,
              lastDetectionAt: Date().addingTimeInterval(-47),
              nearbyDeviceCount: 8)
    }
}

#Preview("Notification", as: .content, using: RadarActivityAttributes.preview) {
    RadarLiveActivity()
} contentStates: {
    RadarActivityAttributes.ContentState.allClear
    RadarActivityAttributes.ContentState.detected
}


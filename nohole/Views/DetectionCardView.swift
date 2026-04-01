import SwiftUI

struct DetectionCardView: View {
    let event: DetectionEvent

    var body: some View {
        HStack(spacing: 12) {
            // Glasses type icon
            Image(systemName: event.glassesType.iconName)
                .font(.title2)
                .foregroundStyle(Color("AccentGreen"))
                .frame(width: 44, height: 44)
                .background(Color("AccentGreen").opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(event.glassesType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let name = event.deviceName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                SignalStrengthView(rssi: event.rssi)
                Text(event.relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .inset(by: 0.5)
                .stroke(Color("AccentGreen").opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        DetectionCardView(event: DetectionEvent(
            id: UUID(),
            timestamp: Date(),
            deviceName: "Ray-Ban | Meta",
            companyID: 0x01AB,
            rssi: -55,
            glassesType: .metaRayBan
        ))
        DetectionCardView(event: DetectionEvent(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-120),
            deviceName: nil,
            companyID: 0x03C2,
            rssi: -78,
            glassesType: .snapSpectacles
        ))
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}

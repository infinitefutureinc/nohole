import SwiftUI

struct SignalStrengthView: View {
    let rssi: Int

    private var barCount: Int {
        switch rssi {
        case -50...0:    return 4  // Strong
        case -65...(-51): return 3  // Good
        case -80...(-66): return 2  // Fair
        default:          return 1  // Weak
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= barCount ? Color("AccentGreen") : Color(.systemGray4))
                    .frame(width: 4, height: CGFloat(bar) * 4 + 4)
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        SignalStrengthView(rssi: -40)
        SignalStrengthView(rssi: -60)
        SignalStrengthView(rssi: -75)
        SignalStrengthView(rssi: -90)
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}

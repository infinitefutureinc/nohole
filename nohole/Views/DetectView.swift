import SwiftUI
import CoreBluetooth

struct DetectView: View {
    @Environment(BLEScanner.self) private var scanner
    @Environment(RadarController.self) private var radar
    @State private var detectionTrigger: UUID?
    @State private var showNearbyDevices = false

    var body: some View {
        NavigationStack {
            Group {
                switch scanner.bluetoothState {
                case .unauthorized:
                    bluetoothDeniedView
                case .poweredOff:
                    bluetoothOffView
                case .unsupported:
                    unsupportedView
                default:
                    scannerContent
                }
            }
            .navigationTitle("Detect")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !scanner.detections.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation { scanner.clearDetections() }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNearbyDevices) {
                nearbyDevicesView
            }
        }
        .tint(.white)
        .onAppear {
            if !radar.isActive && scanner.bluetoothState != .unauthorized
                && scanner.bluetoothState != .unsupported
                && scanner.bluetoothState != .poweredOff {
                Task { await radar.start() }
            }
        }
        .sensoryFeedback(.warning, trigger: detectionTrigger)
        .onChange(of: scanner.latestDetection?.id) { _, newID in
            if let newID {
                detectionTrigger = newID
            }
        }
    }

    // MARK: - Scanner Content

    private var scannerContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status pill
                statusPill
                    .padding(.top, 4)

                // Radar
                RadarPulseView(
                    isScanning: scanner.isScanning,
                    hasDetection: scanner.latestDetection != nil
                )
                .padding(.vertical, 8)

                // Scan button
                scanButton

                // Detection count
                if !scanner.detections.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color("AccentGreen"))
                        Text("\(scanner.detections.count) glasshole\(scanner.detections.count == 1 ? "" : "s") detected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Detection log
                if scanner.detections.isEmpty && scanner.isScanning {
                    VStack(spacing: 12) {
                        Text("Looking for glassholes...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if scanner.nearbyDevices.count > 0 {
                            Button {
                                showNearbyDevices = true
                            } label: {
                                Text("Scanning \(scanner.nearbyDevices.count) device\(scanner.nearbyDevices.count == 1 ? "" : "s") nearby")
                                    .font(.caption)
                                    .foregroundStyle(Color("AccentGreen"))
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(scanner.detections) { event in
                            DetectionCardView(event: event)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(duration: 0.4), value: scanner.detections.count)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Components

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        if radar.isActive { return Color("AccentGreen") }
        if scanner.bluetoothState == .poweredOn { return .secondary }
        return .red
    }

    private var statusText: String {
        if radar.isActive { return "Scanning" }
        if scanner.bluetoothState == .poweredOn { return "Ready" }
        if scanner.bluetoothState == .unknown { return "Initializing" }
        return "Unavailable"
    }

    private var scanButton: some View {
        Button {
            Task {
                if radar.isActive {
                    await radar.stop()
                } else {
                    await radar.start()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: radar.isActive
                    ? "stop.circle.fill"
                    : "antenna.radiowaves.left.and.right")
                    .font(.body.weight(.semibold))
                Text(radar.isActive ? "Stop Scan" : "Start Scan")
                    .fontWeight(.bold)
            }
            .foregroundStyle(radar.isActive ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(radar.isActive ? Color(.systemGray4) : Color("AccentGreen"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    // MARK: - Bluetooth State Views

    private var bluetoothDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bluetooth.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Bluetooth Access Denied")
                .font(.title2)
                .fontWeight(.bold)

            Text("NoGlasshole needs Bluetooth to detect nearby smart glasses. All scanning happens on-device — nothing leaves your phone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("AccentGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var bluetoothOffView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bluetooth")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Turn On Bluetooth")
                .font(.title2)
                .fontWeight(.bold)

            Text("Bluetooth is required to scan for nearby smart glasses. Enable it in Control Center or Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Bluetooth Not Supported")
                .font(.title2)
                .fontWeight(.bold)

            Text("This device does not support Bluetooth Low Energy scanning.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Nearby Devices

    private var nearbyDevicesView: some View {
        NavigationStack {
            Group {
                if scanner.nearbyDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices Yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Start scanning to see all nearby BLE devices.")
                    )
                } else {
                    List(scanner.nearbyDevices) { device in
                        nearbyDeviceRow(device)
                    }
                }
            }
            .navigationTitle("Nearby Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showNearbyDevices = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func nearbyDeviceRow(_ device: NearbyDevice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(device.rssi >= scanner.rssiThreshold ? Color.primary : Color.red)
            }
            HStack {
                if let cid = device.companyID {
                    Text("CID: 0x\(String(cid, radix: 16, uppercase: true))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if device.matched {
                    Text(device.reason)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color("AccentGreen"))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DetectView()
        .environment(RadarController.shared)
        .environment(BLEScanner.shared)
        .preferredColorScheme(.dark)
}

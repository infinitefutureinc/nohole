import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Blur settings
                Section {
                    blurAmountControl
                    
                    Picker("Blur Style", selection: $settings.blurStyle) {
                        ForEach(BlurStyle.allCases) { style in
                            Label(style.rawValue, systemImage: style.iconName)
                                .tag(style)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Mask Coverage")
                            Spacer()
                            Text("\(Int(settings.maskScale * 100))%")
                                .foregroundStyle(.secondary)
                                .font(.subheadline.monospacedDigit())
                        }
                        Slider(value: $settings.maskScale, in: 1.0...2.0, step: 0.1)
                            .tint(Color.accentColor)
                        Text("Larger values cover more area around the face (hair, ears)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Blur Settings", systemImage: "aqi.medium")
                }
                
                // Selective blur
                Section {
                    Toggle(isOn: $settings.selectiveBlurEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selective Blur")
                            Text("Tap faces to un-blur (keep friends visible)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.accentColor)
                } header: {
                    Label("Privacy Controls", systemImage: "hand.raised")
                }
                
                // About
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("NoHole")
                                .font(.title2)
                                .fontWeight(.black)
                            Spacer()
                        }
                        
                        Text("Don't be a glasshole.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("All face detection and blurring runs 100% on-device using Apple's Vision framework. No data ever leaves your phone. No accounts, no tracking, no cloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private extension SettingsView {
    @ViewBuilder
    var blurAmountControl: some View {
        switch settings.blurStyle {
        case .gaussian:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blur Radius")
                    Spacer()
                    Text("\(Int(settings.gaussianBlurRadius))")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }
                Slider(value: $settings.gaussianBlurRadius, in: 10...80, step: 1)
                    .tint(Color.accentColor)
                Text("Higher values smear more facial detail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .pixelate:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pixelation")
                    Spacer()
                    Text("\(Int(settings.blurIntensity))")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }
                Slider(value: $settings.blurIntensity, in: 5...60, step: 1)
                    .tint(Color.accentColor)
            }
        case .solidBlack:
            Text("Solid Black uses a full mask instead of a blur radius.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings())
        .preferredColorScheme(.dark)
}

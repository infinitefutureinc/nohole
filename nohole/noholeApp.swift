import SwiftUI
import StoreKit

@main
struct noholeApp: App {
    @State private var radar = RadarController.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            .environment(radar)
            .environment(radar.scanner)
            .preferredColorScheme(.dark)
            .task {
                try? await SKAdNetwork.updatePostbackConversionValue(0)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            radar.scenePhaseChanged(to: newPhase)
        }
    }
}

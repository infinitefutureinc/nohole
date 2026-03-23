import SwiftUI
import Photos

struct HomeView: View {
    @State var library = PhotoLibraryManager()
    @State var settings = AppSettings()
    @State private var showSettings = false
    @State private var filter: MediaFilter = .all
    
    enum MediaFilter: String, CaseIterable {
        case glasses = "Glasses"
        case all = "All"
    }
    
    // Filter to photos only until video processing is supported
    private var photosOnlySmartGlasses: [MediaItem] {
        library.smartGlassesItems.filter { $0.isPhoto }
    }
    
    private var photosOnlyOther: [MediaItem] {
        library.otherItems.filter { $0.isPhoto }
    }
    
    private var filteredItems: [MediaItem] {
        switch filter {
        case .glasses:
            return photosOnlySmartGlasses
        case .all:
            return library.mediaItems.filter { $0.isPhoto }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch library.authorizationStatus {
                case .authorized, .limited:
                    mediaContent
                case .denied, .restricted:
                    deniedView
                default:
                    requestAccessView
                }
            }
            .navigationTitle("NoHole")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaPreviewView(item: item, library: library, settings: settings)
            }
        }
        .tint(.white)
        .task {
            // Re-check current status in case user granted permission externally
            library.checkCurrentAuthorization()
            
            switch library.authorizationStatus {
            case .notDetermined:
                await library.requestAuthorization()
            case .authorized, .limited:
                if library.mediaItems.isEmpty {
                    await library.fetchMedia()
                }
            default:
                break
            }
        }
    }
    
    private var mediaContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tagline
                Text("Don't be a glasshole.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                if library.isLoading {
                    ProgressView("Loading media...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    // Smart glasses section
                    if !photosOnlySmartGlasses.isEmpty {
                        sectionHeader(
                            title: "Smart Glasses",
                            icon: "eyeglasses",
                            count: photosOnlySmartGlasses.count
                        )
                        MediaGridView(
                            items: photosOnlySmartGlasses,
                            title: "Smart Glasses",
                            library: library
                        )
                    }
                    
                    // All photos section
                    if !photosOnlyOther.isEmpty {
                        sectionHeader(
                            title: "All Photos",
                            icon: "photo.on.rectangle",
                            count: photosOnlyOther.count
                        )
                        MediaGridView(
                            items: photosOnlyOther,
                            title: "All Photos",
                            library: library
                        )
                    }
                    
                    if photosOnlySmartGlasses.isEmpty && photosOnlyOther.isEmpty {
                        ContentUnavailableView(
                            "No Photos",
                            systemImage: "photo.badge.exclamationmark",
                            description: Text("No photos found in your library.")
                        )
                        .padding(.top, 40)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await library.fetchMedia()
        }
    }
    
    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("NoHole needs access to your photos to detect and blur faces. All processing happens on-device — nothing leaves your phone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await library.requestAuthorization()
                }
            } label: {
                Text("Grant Access")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var deniedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.lock")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Access Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please enable photo access in Settings to use NoHole.")
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
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}

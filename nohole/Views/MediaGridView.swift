import SwiftUI
import Photos

struct MediaGridView: View {
    let items: [MediaItem]
    let title: String
    let library: PhotoLibraryManager
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    MediaThumbnailView(item: item, library: library)
                }
            }
        }
    }
}

struct MediaThumbnailView: View {
    let item: MediaItem
    let library: PhotoLibraryManager
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: geo.size.width, height: geo.size.width)
                }
                
                // Video duration badge
                if item.isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(formatDuration(item.duration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
                }
                
                // Smart glasses badge
                if item.isSmartGlasses {
                    VStack {
                        HStack {
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(4)
                                .background(Color("AccentGreen"))
                                .clipShape(Circle())
                                .padding(4)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let size = CGSize(width: 300, height: 300)
        library.requestImage(for: item.asset, targetSize: size) { image in
            self.thumbnail = image
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

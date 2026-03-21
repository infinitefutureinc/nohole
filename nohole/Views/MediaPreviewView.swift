import SwiftUI
import Photos
import AVKit

struct MediaPreviewView: View {
    let item: MediaItem
    let library: PhotoLibraryManager
    let settings: AppSettings
    
    @State private var originalImage: UIImage?
    @State private var blurredImage: UIImage?
    @State private var detectedFaces: [DetectedFace] = []
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var showShareSheet = false
    @State private var savedSuccessfully = false
    @State private var errorMessage: String?
    @State private var shareItems: [Any] = []
    
    // Video states
    @State private var videoProcessor = VideoBlurProcessor()
    @State private var processedVideoURL: URL?
    @State private var avAsset: AVAsset?
    @State private var player: AVPlayer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if item.isPhoto {
                    photoPreview
                } else {
                    videoPreview
                }
                
                // Face count info
                if !detectedFaces.isEmpty {
                    HStack {
                        Image(systemName: "face.dashed")
                        Text("\(detectedFaces.count) face\(detectedFaces.count == 1 ? "" : "s") detected")
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                }
                
                // Selective blur controls
                if settings.selectiveBlurEnabled && !detectedFaces.isEmpty && item.isPhoto {
                    selectiveBlurControls
                }
                
                // Action buttons
                actionButtons
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                if savedSuccessfully {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved to Photos")
                            .font(.subheadline)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(item.isSmartGlasses ? "Smart Glasses" : "Media")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if item.isSmartGlasses {
                    Label("Smart Glasses", systemImage: "eyeglasses")
                        .foregroundStyle(Color.accentColor)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
            }
        }
        .task {
            await loadMedia()
        }
    }
    
    // MARK: - Photo Preview
    
    private var photoPreview: some View {
        Group {
            if let image = blurredImage ?? originalImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
            } else if isProcessing {
                ProgressView("Processing faces...")
                    .frame(height: 300)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(CGFloat(item.pixelWidth) / CGFloat(item.pixelHeight), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }
    
    // MARK: - Video Preview
    
    private var videoPreview: some View {
        VStack(spacing: 12) {
            if let player = player, processedVideoURL != nil {
                VideoPlayer(player: player)
                    .aspectRatio(CGFloat(item.pixelWidth) / CGFloat(item.pixelHeight), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
            } else if videoProcessor.isProcessing {
                VStack(spacing: 16) {
                    ProgressView(value: videoProcessor.progress)
                        .tint(Color.accentColor)
                        .padding(.horizontal)
                    
                    Text("Processing video... \(Int(videoProcessor.progress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            } else {
                // Show thumbnail while not processed
                if let image = originalImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .overlay { ProgressView() }
                }
                
                Button {
                    Task { await processVideo() }
                } label: {
                    Label("Process Video", systemImage: "wand.and.stars")
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Selective Blur
    
    private var selectiveBlurControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap faces to un-blur")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(detectedFaces.enumerated()), id: \.element.id) { index, face in
                        Button {
                            detectedFaces[index].isBlurred.toggle()
                            Task { await reprocessPhoto() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: face.isBlurred ? "eye.slash.fill" : "eye.fill")
                                    .font(.title3)
                                Text("Face \(index + 1)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(face.isBlurred ? .secondary : Color.accentColor)
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(face.isBlurred ? Color.clear : Color.accentColor, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Save button
            Button {
                Task { await saveMedia() }
            } label: {
                Label(isSaving ? "Saving..." : "Save", systemImage: "square.and.arrow.down")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSaving || (item.isPhoto && blurredImage == nil) || (item.isVideo && processedVideoURL == nil))
            
            // Share button
            Button {
                prepareShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled((item.isPhoto && blurredImage == nil) || (item.isVideo && processedVideoURL == nil))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func loadMedia() async {
        if item.isPhoto {
            await loadAndProcessPhoto()
        } else {
            // Load video thumbnail
            let size = CGSize(width: item.pixelWidth, height: item.pixelHeight)
            library.requestImage(for: item.asset, targetSize: size) { image in
                self.originalImage = image
            }
            // Pre-load the AVAsset
            avAsset = await library.requestAVAsset(for: item.asset)
        }
    }
    
    private func loadAndProcessPhoto() async {
        isProcessing = true
        
        guard let image = await library.requestFullImage(for: item.asset) else {
            isProcessing = false
            return
        }
        
        originalImage = image
        
        do {
            detectedFaces = try await FaceDetectionService.detectFaces(in: image)
            
            if let processed = ImageBlurProcessor.blurFaces(
                in: image,
                faces: detectedFaces,
                style: settings.blurStyle,
                intensity: settings.blurIntensity,
                maskScale: settings.maskScale
            ) {
                let watermarked = WatermarkRenderer.addWatermark(to: processed)
                blurredImage = watermarked
            } else {
                blurredImage = WatermarkRenderer.addWatermark(to: image)
            }
        } catch {
            errorMessage = "Face detection failed: \(error.localizedDescription)"
            blurredImage = WatermarkRenderer.addWatermark(to: image)
        }
        
        isProcessing = false
    }
    
    private func reprocessPhoto() async {
        guard let image = originalImage else { return }
        
        if let processed = ImageBlurProcessor.blurFaces(
            in: image,
            faces: detectedFaces,
            style: settings.blurStyle,
            intensity: settings.blurIntensity,
            maskScale: settings.maskScale
        ) {
            blurredImage = WatermarkRenderer.addWatermark(to: processed)
        }
    }
    
    private func processVideo() async {
        guard let avAsset = avAsset else {
            errorMessage = "Failed to load video"
            return
        }
        
        do {
            let outputURL = try await videoProcessor.processVideo(
                asset: avAsset,
                style: settings.blurStyle,
                intensity: settings.blurIntensity,
                maskScale: settings.maskScale
            )
            
            processedVideoURL = outputURL
            player = AVPlayer(url: outputURL)
            player?.play()
        } catch {
            errorMessage = "Video processing failed: \(error.localizedDescription)"
        }
    }
    
    private func saveMedia() async {
        isSaving = true
        savedSuccessfully = false
        errorMessage = nil
        
        do {
            if item.isPhoto, let image = blurredImage {
                try await library.saveImageToLibrary(image)
            } else if let url = processedVideoURL {
                try await library.saveVideoToLibrary(at: url)
            }
            withAnimation { savedSuccessfully = true }
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    private func prepareShare() {
        if item.isPhoto, let image = blurredImage {
            shareItems = [image]
            showShareSheet = true
        } else if let url = processedVideoURL {
            shareItems = [url]
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

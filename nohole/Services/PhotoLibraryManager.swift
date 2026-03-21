import Foundation
import Photos
import UIKit

@Observable
final class PhotoLibraryManager {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var mediaItems: [MediaItem] = []
    var smartGlassesItems: [MediaItem] = []
    var otherItems: [MediaItem] = []
    var isLoading: Bool = false
    
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        if status == .authorized || status == .limited {
            await fetchMedia()
        }
    }
    
    func fetchMedia() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                              PHAssetMediaType.image.rawValue,
                                              PHAssetMediaType.video.rawValue)
        
        let results = PHAsset.fetchAssets(with: fetchOptions)
        
        // Step 1: Check for Meta AI / Ray-Ban albums (fastest, most reliable signal)
        let metaAlbumIDs = SmartGlassesDetector.findMetaAlbumAssetIDs()
        
        // Step 2: Collect all assets
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        // Step 3: Classify using album membership + video resolution
        var allItems: [MediaItem] = []
        var glasses: [MediaItem] = []
        var other: [MediaItem] = []
        var photoCandidates: [(index: Int, asset: PHAsset)] = []
        
        for asset in assets {
            // Album match is the strongest signal
            let inMetaAlbum = metaAlbumIDs.contains(asset.localIdentifier)
            let videoMatch = SmartGlassesDetector.isSmartGlassesMedia(asset)
            let filenameMatch = SmartGlassesDetector.checkFilenameForSmartGlasses(asset: asset)
            let isGlasses = inMetaAlbum || videoMatch || filenameMatch
            
            let item = MediaItem(
                id: asset.localIdentifier,
                asset: asset,
                isSmartGlasses: isGlasses
            )
            allItems.append(item)
            
            if isGlasses {
                glasses.append(item)
            } else if asset.mediaType == .image {
                // Could be smart glasses photo — need deeper EXIF check
                photoCandidates.append((index: allItems.count - 1, asset: asset))
                other.append(item)
            } else {
                other.append(item)
            }
        }
        
        // Show results immediately, then refine with EXIF checks
        await MainActor.run {
            self.mediaItems = allItems
            self.smartGlassesItems = glasses
            self.otherItems = other
            self.isLoading = false
        }
        
        // Run EXIF checks on photo candidates in batches
        let batchSize = 10
        var foundGlasses: [MediaItem] = []
        var foundGlassesIDs: Set<String> = []
        
        for batchStart in stride(from: 0, to: photoCandidates.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, photoCandidates.count)
            let batch = photoCandidates[batchStart..<batchEnd]
            
            await withTaskGroup(of: (Int, Bool).self) { group in
                for candidate in batch {
                    group.addTask {
                        let isGlasses = await SmartGlassesDetector.checkEXIFForSmartGlasses(asset: candidate.asset)
                        return (candidate.index, isGlasses)
                    }
                }
                
                for await (index, isGlasses) in group {
                    if isGlasses {
                        let updatedItem = MediaItem(
                            id: allItems[index].id,
                            asset: allItems[index].asset,
                            isSmartGlasses: true
                        )
                        allItems[index] = updatedItem
                        foundGlasses.append(updatedItem)
                        foundGlassesIDs.insert(updatedItem.id)
                    }
                }
            }
        }
        
        // Update lists if any glasses photos were found via EXIF
        if !foundGlasses.isEmpty {
            let updatedGlasses = glasses + foundGlasses
            let updatedOther = other.filter { !foundGlassesIDs.contains($0.id) }
            
            await MainActor.run {
                self.mediaItems = allItems
                self.smartGlassesItems = updatedGlasses
                self.otherItems = updatedOther
            }
        }
    }
    
    func requestImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    func requestFullImage(for asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    func requestAVAsset(for phAsset: PHAsset) async -> AVAsset? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(
                forVideo: phAsset,
                options: options
            ) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }
    
    func saveImageToLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    func saveVideoToLibrary(at url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}

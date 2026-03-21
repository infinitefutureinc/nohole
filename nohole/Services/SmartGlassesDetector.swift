import Foundation
import Photos
import ImageIO

struct SmartGlassesDetector {
    
    // Known album names the Meta AI app may create
    private static let metaAlbumNames: Set<String> = [
        "Meta AI", "Meta View", "Ray-Ban Meta",
        "Ray-Ban Stories", "Ray-Ban", "Meta"
    ]
    
    // Ray-Ban Meta video: 2880x2160 (2.88K) — iPhones don't shoot this resolution
    // Also 1920x1440 (4:3 at 1080p) which is unusual for phones
    private static let metaVideoResolutions: Set<String> = [
        "2880x2160", "2160x2880",
        "1920x1440", "1440x1920"
    ]
    
    /// Quick resolution-only check. Only reliable for video (unique resolutions).
    /// Photos share 3024x4032 with iPhones so resolution alone isn't enough.
    static func isSmartGlassesMedia(_ asset: PHAsset) -> Bool {
        if asset.mediaType == .video {
            let key = "\(asset.pixelWidth)x\(asset.pixelHeight)"
            return metaVideoResolutions.contains(key)
        }
        return false
    }
    
    /// Find the set of asset IDs that belong to Meta AI / Ray-Ban albums
    static func findMetaAlbumAssetIDs() -> Set<String> {
        var ids = Set<String>()
        
        // Search user-created albums for known Meta names
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        
        userAlbums.enumerateObjects { collection, _, _ in
            guard let title = collection.localizedTitle?.lowercased() else { return }
            
            for name in metaAlbumNames {
                if title.contains(name.lowercased()) {
                    let assets = PHAsset.fetchAssets(in: collection, options: nil)
                    assets.enumerateObjects { asset, _, _ in
                        ids.insert(asset.localIdentifier)
                    }
                    break
                }
            }
        }
        
        // Also check synced albums (some third-party apps use this)
        let syncedAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumSyncedEvent,
            options: nil
        )
        
        syncedAlbums.enumerateObjects { collection, _, _ in
            guard let title = collection.localizedTitle?.lowercased() else { return }
            
            for name in metaAlbumNames {
                if title.contains(name.lowercased()) {
                    let assets = PHAsset.fetchAssets(in: collection, options: nil)
                    assets.enumerateObjects { asset, _, _ in
                        ids.insert(asset.localIdentifier)
                    }
                    break
                }
                }
        }
        
        return ids
    }
    
    /// Check original filename for Meta AI patterns.
    /// The Meta AI app may use distinctive naming like "meta_", "rayban_", etc.
    static func checkFilenameForSmartGlasses(asset: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            let filename = resource.originalFilename.lowercased()
            if filename.contains("meta") || filename.contains("rayban") ||
               filename.contains("ray-ban") || filename.contains("ray_ban") {
                return true
            }
        }
        return false
    }
    
    /// Full EXIF-based detection. Checks Make/Model/Software fields.
    static func checkEXIFForSmartGlasses(asset: PHAsset) async -> Bool {
        guard asset.mediaType == .image else {
            return isSmartGlassesMedia(asset)
        }
        
        // First do the quick filename check (doesn't require loading the full image)
        if checkFilenameForSmartGlasses(asset: asset) {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true
            
            asset.requestContentEditingInput(with: options) { input, _ in
                guard let input = input,
                      let url = input.fullSizeImageURL else {
                    continuation.resume(returning: false)
                    return
                }
                
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
                    continuation.resume(returning: false)
                    return
                }
                
                // Check TIFF dictionary: Make, Model, Software
                if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    let make = (tiffDict[kCGImagePropertyTIFFMake as String] as? String)?.lowercased() ?? ""
                    let model = (tiffDict[kCGImagePropertyTIFFModel as String] as? String)?.lowercased() ?? ""
                    let software = (tiffDict[kCGImagePropertyTIFFSoftware as String] as? String)?.lowercased() ?? ""
                    
                    let searchTerms = ["meta", "ray-ban", "rayban", "wayfarer", "headliner", "stories"]
                    for term in searchTerms {
                        if make.contains(term) || model.contains(term) || software.contains(term) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                    
                    // If Make is empty or unrecognized but not Apple/Samsung/Google,
                    // and resolution matches 3024x4032, it could be glasses
                    let knownPhoneMakes = ["apple", "samsung", "google", "huawei", "xiaomi", "oneplus", "oppo", "vivo", "motorola", "lg", "sony"]
                    let isKnownPhone = knownPhoneMakes.contains(where: { make.contains($0) })
                    if !isKnownPhone && !make.isEmpty {
                        // Unknown make with matching resolution — likely smart glasses
                        let w = asset.pixelWidth
                        let h = asset.pixelHeight
                        if (w == 3024 && h == 4032) || (w == 4032 && h == 3024) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
                
                // Check EXIF dictionary: LensMake, LensModel
                if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    let lensMake = (exifDict[kCGImagePropertyExifLensMake as String] as? String)?.lowercased() ?? ""
                    let lensModel = (exifDict[kCGImagePropertyExifLensModel as String] as? String)?.lowercased() ?? ""
                    
                    let searchTerms = ["meta", "ray-ban", "rayban", "qualcomm", "snapdragon"]
                    for term in searchTerms {
                        if lensMake.contains(term) || lensModel.contains(term) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                    
                    // Smart glasses photos typically lack detailed lens info that phones have
                    // If there's no focal length info and no lens model but it's 3024x4032,
                    // and TIFF Make is empty — it's suspicious
                    let focalLength = exifDict[kCGImagePropertyExifFocalLength as String]
                    let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
                    let make = (tiffDict?[kCGImagePropertyTIFFMake as String] as? String) ?? ""
                    
                    if focalLength == nil && lensModel.isEmpty && make.isEmpty {
                        let w = asset.pixelWidth
                        let h = asset.pixelHeight
                        if (w == 3024 && h == 4032) || (w == 4032 && h == 3024) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
                
                continuation.resume(returning: false)
            }
        }
    }
}

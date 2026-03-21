import Foundation
import Photos
import ImageIO

struct SmartGlassesDetector {
    
    // MARK: - Known Meta AI identifiers (from real device metadata)
    
    // EXIF Make/Model from actual Ray-Ban Meta photos:
    //   Make: "Meta AI"
    //   Model: "Ray-Ban Meta Smart Glasses"
    private static let exifMakeKeywords = ["meta ai"]
    private static let exifModelKeywords = ["ray-ban meta", "meta smart glasses"]
    
    // Filename patterns from Meta AI app imports:
    //   Photos: "photo-{id}_singular_display_fullPicture.HEIC"
    //   Videos: "od_video-{id}_singular_display.MOV"
    private static let filenamePatterns = [
        "singular_display",
        "photo-", // followed by number and _singular_display
        "od_video-"
    ]
    
    // Album name used by the Meta AI app
    private static let metaAlbumNames: Set<String> = [
        "meta ai", "meta view", "ray-ban meta",
        "ray-ban stories", "ray-ban"
    ]
    
    // MARK: - Quick checks (no async, no I/O)
    
    /// Fast check using only PHAsset properties and filename.
    /// Checks filename pattern + album membership.
    static func isSmartGlassesMedia(_ asset: PHAsset) -> Bool {
        return checkFilenameForSmartGlasses(asset: asset)
    }
    
    /// Find all asset IDs that belong to a Meta AI / Ray-Ban album
    static func findMetaAlbumAssetIDs() -> Set<String> {
        var ids = Set<String>()
        
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        
        userAlbums.enumerateObjects { collection, _, _ in
            guard let title = collection.localizedTitle?.lowercased() else { return }
            
            if metaAlbumNames.contains(where: { title.contains($0) }) {
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                assets.enumerateObjects { asset, _, _ in
                    ids.insert(asset.localIdentifier)
                }
            }
        }
        
        return ids
    }
    
    /// Check original filename for Meta AI naming patterns
    nonisolated static func checkFilenameForSmartGlasses(asset: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            let filename = resource.originalFilename.lowercased()
            
            // Primary signal: "singular_display" appears in all Meta glasses filenames
            if filename.contains("singular_display") {
                return true
            }
            
            // Photo pattern: "photo-NNN_..."
            if filename.hasPrefix("photo-") && filename.hasSuffix(".heic") {
                return true
            }
            
            // Video pattern: "od_video-NNN_..."
            if filename.hasPrefix("od_video-") {
                return true
            }
        }
        return false
    }
    
    // MARK: - Deep EXIF check (async, for photos)
    
    /// Reliable EXIF-based detection using confirmed Make/Model values.
    static func checkEXIFForSmartGlasses(asset: PHAsset) async -> Bool {
        // Quick checks first
        if checkFilenameForSmartGlasses(asset: asset) {
            return true
        }
        
        guard asset.mediaType == .image else {
            return false
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
                
                // Check TIFF Make/Model — confirmed values from real device:
                //   Make = "Meta AI", Model = "Ray-Ban Meta Smart Glasses"
                if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    let make = (tiffDict[kCGImagePropertyTIFFMake as String] as? String)?.lowercased() ?? ""
                    let model = (tiffDict[kCGImagePropertyTIFFModel as String] as? String)?.lowercased() ?? ""
                    
                    for keyword in exifMakeKeywords {
                        if make.contains(keyword) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                    
                    for keyword in exifModelKeywords {
                        if model.contains(keyword) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
                
                // Check EXIF LensMake/LensModel as fallback
                if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    let lensMake = (exifDict[kCGImagePropertyExifLensMake as String] as? String)?.lowercased() ?? ""
                    let lensModel = (exifDict[kCGImagePropertyExifLensModel as String] as? String)?.lowercased() ?? ""
                    
                    if lensMake.contains("meta") || lensModel.contains("meta") ||
                       lensModel.contains("ray-ban") {
                        continuation.resume(returning: true)
                        return
                    }
                }
                
                continuation.resume(returning: false)
            }
        }
    }
}

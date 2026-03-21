import Foundation
import Photos
import UIKit

struct MediaItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let isSmartGlasses: Bool
    
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    var isPhoto: Bool {
        asset.mediaType == .image
    }
    
    var creationDate: Date? {
        asset.creationDate
    }
    
    var pixelWidth: Int {
        asset.pixelWidth
    }
    
    var pixelHeight: Int {
        asset.pixelHeight
    }
    
    var duration: TimeInterval {
        asset.duration
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

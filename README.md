# NoGlasshole

A privacy-first iOS app that detects nearby smart glasses via Bluetooth and blurs faces in photos and videos. All processing happens entirely on-device — no cloud, no accounts, no data leaves your phone.

## Features

### Smart Glasses Detection
- Real-time Bluetooth Low Energy (BLE) scanning to identify nearby smart glasses
- Recognizes Meta Ray-Ban, Snap Spectacles, and other smart eyewear using manufacturer advertisement data
- Live radar UI with signal strength and detection log

### Face Blur for Photos & Videos
- Automatic face detection powered by Apple's Vision framework
- Three blur modes: Gaussian blur, pixelation, and solid black mask
- Selective blur — tap to un-blur specific faces while keeping others obscured
- Adjustable blur intensity and mask coverage
- Video processing with temporal face stabilization to prevent flickering across frames

### Smart Glasses Media Detection
- Scans your photo library for media imported from smart glasses
- Identifies Ray-Ban Meta photos via EXIF metadata and filename patterns
- Organized view separating smart glasses media from the rest of your library

## Tech Stack

- **SwiftUI** — UI framework
- **Vision** — Face detection with GPU/CPU fallback
- **Core Image** — Image and video filtering
- **AVFoundation** — Video composition and export
- **CoreBluetooth** — BLE scanning for smart glasses detection
- **PhotoKit** — Photo library access and EXIF parsing

## Requirements

- iOS 17.0+
- Xcode 15+

## Getting Started

1. Clone the repository
2. Open `nohole.xcodeproj` in Xcode
3. Build and run on a physical device (BLE scanning requires a real device)

## Privacy

NoGlasshole processes everything on-device. No data is uploaded, no accounts are required, and no network requests are made.

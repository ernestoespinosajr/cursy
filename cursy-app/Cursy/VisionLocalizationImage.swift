import AppKit

/// A localization request owns the exact raster whose pixels the provider returns.
/// Kept separate from the higher-resolution conversational screenshot.
struct VisionLocalizationImage {
    let data: Data
    let width: Int
    let height: Int

    // Keep the raster bounds used by the measured provider comparison (inherited
    // from GPT-4.1). The new locator receives this exact raster at original detail.
    // Increasing resolution is a separate evaluation, not an implicit transform.
    static func pixelSize(width: Int, height: Int) -> CGSize {
        guard width > 0, height > 0 else { return .zero }
        let scale = min(1, 768 / Double(min(width, height)), 2048 / Double(max(width, height)))
        return CGSize(width: max(1, floor(Double(width) * scale)),
                      height: max(1, floor(Double(height) * scale)))
    }

    static func prepare(_ data: Data) throws -> Self {
        guard let source = NSBitmapImageRep(data: data)?.cgImage else {
            throw URLError(.cannotDecodeContentData)
        }
        let size = pixelSize(width: source.width, height: source.height)
        let width = Int(size.width), height = Int(size.height)
        guard let drawing = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw URLError(.cannotDecodeContentData)
        }
        drawing.interpolationQuality = .high
        drawing.draw(source, in: CGRect(origin: .zero, size: size))
        guard let image = drawing.makeImage(),
              let encoded = NSBitmapImageRep(cgImage: image).representation(
                using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw URLError(.cannotDecodeContentData)
        }
        return Self(data: encoded, width: width, height: height)
    }
}

import AppKit

// Local Apple-platform UI preview only. Never substitute look-alike web icons.
@main
struct RenderSymbols {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let names = ["xmark", "sidebar.left", "cursorarrow.motionlines", "mic", "control",
                     "option", "rectangle", "gearshape", "macwindow.on.rectangle", "chevron.up",
                     "chevron.down", "chevron.left", "plus", "hand.raised", "bubble.left.and.bubble.right",
                     "checkmark", "arrow.clockwise", "cursorarrow", "circle", "waveform", "checkmark.circle.fill"]
        for name in names {
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))),
                  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 96, pixelsHigh: 96,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
                throw NSError(domain: "SymbolPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: name])
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            let scale = 76 / max(symbol.size.width, symbol.size.height)
            let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            symbol.draw(in: NSRect(x: (96 - size.width) / 2, y: (96 - size.height) / 2,
                                  width: size.width, height: size.height))
            NSGraphicsContext.restoreGraphicsState()
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "SymbolPreview", code: 2)
            }
            try png.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}

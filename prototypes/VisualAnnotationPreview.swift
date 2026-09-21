// Offline static QA sheet. Compile with VisualAnnotation.swift and ScreenCoordinateSpace.swift.
// No live screen capture, credentials, provider requests or microphone.
import AppKit
import SwiftUI

@main
struct VisualAnnotationPreview {
    @MainActor static func main() throws {
        let sheet = VStack(spacing: 16) {
            Text("Cursy · Anotaciones visuales").font(.title2.bold())
            HStack(spacing: 16) {
                column(dark: false)
                column(dark: true)
            }
        }.padding(24).background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }

    @MainActor static func column(dark: Bool) -> some View {
        VStack(spacing: 12) {
            ForEach([VisualAnnotationStyle.circle, .arrow, .rectangle, .label]) { style in
                ZStack(alignment: .topLeading) {
                    Color(nsColor: dark ? .darkGray : .white)
                    Text(style.title(spanish: true)).font(.caption).padding(12)
                    Text("Guardar").font(.system(size: 13)).padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)))
                        .position(x: 190, y: 78)
                    if let annotation = VisualAnnotation(style: style, point: CGPoint(x: 190, y: 112),
                        displayFrame: CGRect(x: 0, y: 0, width: 380, height: 190), label: "Guardar cambios",
                        region: CGRect(x: 152, y: 96, width: 76, height: 32)) {
                        VisualAnnotationView(annotation: annotation, elapsed: 4, pointer: CGPoint(x: 170, y: 85))
                    }
                }
                .frame(width: 380, height: 190).clipShape(RoundedRectangle(cornerRadius: 12))
                .environment(\.colorScheme, dark ? .dark : .light)
            }
        }
    }
}

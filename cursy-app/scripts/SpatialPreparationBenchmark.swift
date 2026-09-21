import AppKit
import Foundation
@testable import Cursy

/// Offline serialization/encoding benchmark, NOT physical feedback or model latency.
@main
struct SpatialPreparationBenchmark {
    @MainActor static func main() throws {
        let width = 1920, height = 1200
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        for index in 0..<120 {
            NSColor(calibratedRed: CGFloat(index % 7) / 7,
                    green: CGFloat(index % 11) / 11, blue: CGFloat(index % 13) / 13, alpha: 1).setFill()
            NSRect(x: index % 12 * 160 + 8, y: index / 12 * 120 + 8, width: 130, height: 85).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!
        let sessionID = ConversationSessionID(), turnID = ConversationTurnID()
        func packet(revision: Int, captureID: String, displayID: UInt32) -> SpatialContextPacket {
            SpatialContextPacket(sessionID: sessionID.rawValue.uuidString,
                turnID: turnID.rawValue.uuidString, captureID: captureID, displayID: displayID,
                sceneRevision: revision, imageWidth: width, imageHeight: height,
                points: (0..<128).map { index in
                    let angle = Double(index) / 127 * 2 * .pi
                    return [0.4 + 0.15 * cos(angle), 0.4 + 0.15 * sin(angle), Double(revision * 4000 + index * 10)]
                })
        }
        var context = VisualTurnContext(captureID: UUID().uuidString, displayID: 2,
            displayFrame: CGRect(x: -1920, y: 200, width: width, height: height),
            capturedAt: .now, imageData: image, imageWidth: width, imageHeight: height)
        context.spatialSessionID = sessionID; context.spatialTurnID = turnID
        context.spatialRevision = 2; context.spatialDeliveryState = .attached
        context.spatialInput = packet(revision: 2, captureID: context.captureID, displayID: 2)
        context.spatialHistory = (0..<2).map { revision in
            SpatialSceneEvidence(imageData: image,
                packet: packet(revision: revision, captureID: UUID().uuidString, displayID: 1),
                observedMilliseconds: revision * 4000 + 1500)
        }
        var reports: [[String: Any]] = []
        for historyCount in [0, 2] {
            var fixture = context
            fixture.spatialHistory = Array(context.spatialHistory.prefix(historyCount))
            _ = OpenAIRealtimeVoiceClient.visualInputMessage(context: fixture) // warmup
            var timings: [Double] = []
            var payloadBytes = 0
            for _ in 0..<30 {
                let start = ProcessInfo.processInfo.systemUptime
                let event = OpenAIRealtimeVoiceClient.visualInputMessage(context: fixture)
                let data = try JSONSerialization.data(withJSONObject: event)
                timings.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
                payloadBytes = data.count
                let item = event["item"] as! [String: Any]
                let parts = item["content"] as! [[String: Any]]
                precondition(parts.filter { $0["type"] as? String == "input_image" }.count == (historyCount + 1) * 2)
            }
            timings.sort()
            reports.append(["historicalScenes": historyCount, "samples": timings.count,
                            "p50Milliseconds": timings[14], "p95Milliseconds": timings[28],
                            "maxMilliseconds": timings.last!, "webSocketJSONBytes": payloadBytes])
        }
        let report: [String: Any] = ["scope": "synthetic image preparation plus JSON serialization only",
            "width": width, "height": height, "pointsPerScene": 128, "results": reports,
            "excluded": ["screen capture", "UI presentation", "network", "model inference", "voice", "cost"]]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}

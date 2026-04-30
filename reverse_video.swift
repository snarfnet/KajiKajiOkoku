import AVFoundation
import Foundation

// AVMutableComposition を使って動画を逆再生版に変換するスクリプト
// 動画を小さなセグメントに分割して逆順に並べる

let inputPath  = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let inputURL  = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

// 既に存在する場合は削除
try? FileManager.default.removeItem(at: outputURL)

let asset = AVURLAsset(url: inputURL)
let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        let duration = try await asset.load(.duration)
        let tracks   = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { fatalError("no video track") }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let fps: Float64 = 30
        let segDurSec = 1.0 / fps
        let segDur = CMTime(seconds: segDurSec, preferredTimescale: 600)

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { fatalError("failed to add track") }

        // セグメントを逆順に挿入
        var insertAt = CMTime.zero
        var segStart = CMTimeSubtract(duration, segDur)
        while segStart >= .zero {
            let segRange = CMTimeRange(start: segStart, duration: segDur)
            try compVideoTrack.insertTimeRange(segRange, of: videoTrack, at: insertAt)
            insertAt  = CMTimeAdd(insertAt, segDur)
            segStart  = CMTimeSubtract(segStart, segDur)
        }

        // ビデオコンポジション（向き修正）
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // エクスポート
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { fatalError("no session") }

        session.outputURL         = outputURL
        session.outputFileType    = .mp4
        session.videoComposition  = videoComposition

        await session.export()
        if let err = session.error {
            print("Export error:", err)
        } else {
            print("Done:", outputPath)
        }
    } catch {
        print("Error:", error)
    }
    semaphore.signal()
}

semaphore.wait()

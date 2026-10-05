//
//  QRImageDecoder.swift
//  OPToolkit
//
//  写真（画像データ）に写っているQRコードを読み取る。Vision標準機能のみで実装。
//  Visionで見つからなかった場合は、CoreImageのCIDetectorでもう一度試す。
//

import CoreImage
import Foundation
import Vision

enum QRImageDecoder {
    /// 画像内のQRコードの文字列を返す。見つからなければnil。
    /// 重い処理なので、メインスレッド以外で実行する。
    /// プロジェクトの既定のアクター隔離がMainActorでも、バックグラウンドで動かせるよう nonisolated にしている。
    nonisolated static func decode(imageData: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            detectWithVision(imageData) ?? detectWithCoreImage(imageData)
        }.value
    }

    private nonisolated static func detectWithVision(_ data: Data) -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(data: data, options: [:])
        guard (try? handler.perform([request])) != nil else { return nil }
        return request.results?.compactMap { $0.payloadStringValue }.first
    }

    private nonisolated static func detectWithCoreImage(_ data: Data) -> String? {
        guard let image = CIImage(data: data),
              let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: nil,
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else { return nil }

        return detector.features(in: image)
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first
    }
}

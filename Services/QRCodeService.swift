//
//  QRCodeService.swift
//  OPToolkit
//
//  CoreImageのCIFilter(qrCodeGenerator)を使ったQRコード生成。
//  外部ライブラリ不要でiOS標準機能のみで完結する。
//

import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeService {
    /// 文字列からQRコードのUIImageを生成する。scaleを上げるほど高解像度になる。
    static func generate(from string: String, scale: CGFloat = 10) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

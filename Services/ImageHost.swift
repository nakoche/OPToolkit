//
//  ImageHost.swift
//  OPToolkit
//
//  カード画像の配信元URLを一元管理する。
//  個人利用の前提で、公式サイトの画像URLを直接参照する。
//  画像の命名規則は「カード番号.png」（パラレル版は _p1, _p2 …、再録は _r1 など）。
//  Card.cardNumberが "OP01-001_p1" のようにこの命名と揃っているので、
//  imageNameが未設定ならcardNumberから自動で組み立てる。
//
//  ※ このURLパターンは第三者のデータセットで確認できた英語版公式サイトの形式から推定したもの。
//    日本語版で表示されない場合は、ブラウザで公式サイトの画像を開いて実際のURLを確認し、
//    baseURLを差し替える。
//

import Foundation

enum ImageHost {
    static let baseURL = URL(string: "https://www.onepiece-cardgame.com/images/cardlist/card/")!
}

extension Card {
    /// カード画像のURL。imageNameがあればそれを、なければcardNumberから "OP01-001.png" の形で組み立てる。
    var imageURL: URL? {
        let fileName: String
        if let imageName, !imageName.isEmpty {
            fileName = imageName
        } else {
            fileName = "\(cardNumber).png"
        }
        return ImageHost.baseURL.appendingPathComponent(fileName)
    }
}

//
//  ImageCacheConfig.swift
//  OPToolkit
//
//  Kingfisherのキャッシュ設定。アプリ起動時に1回だけ呼び出す。
//  呼び出し場所の例: OPToolkitApp.init()
//
//      @main
//      struct OPToolkitApp: App {
//          init() {
//              ImageCacheConfig.configure()
//          }
//          var body: some Scene { ... }
//      }
//

import Foundation
import Kingfisher

enum ImageCacheConfig {
    static func configure() {
        let cache = ImageCache.default

        // ディスクキャッシュ: 最大500MB、30日で自動失効
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(30)

        // メモリキャッシュ: 最大100MB
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
        cache.memoryStorage.config.expiration = .seconds(300)

        // ネットワーク不調時の挙動: タイムアウトを少し長めに
        KingfisherManager.shared.downloader.downloadTimeout = 15
    }
}

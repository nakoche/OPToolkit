//
//  DeckImagePreviewModal.swift
//  OPToolkit
//
//  「画像表示ボタン」から開くモーダル。生成したデッキ画像を表示し、
//  端末の写真ライブラリへ保存できるボタンを備える。
//  CardDetailModalと同じ「全画面オーバーレイ＋下部固定ボタン」の方式。
//
//  PhotosフレームワークのPHPhotoLibraryを使い、追加専用(.addOnly)の権限で保存する。
//  Info.plistへの NSPhotoLibraryAddUsageDescription の追加が必須
//  （未設定だと保存がクラッシュまたは失敗する）。
//

import Photos
import SwiftUI

struct DeckImagePreviewModal: View {
    let image: UIImage
    let onClose: () -> Void

    @State private var resultMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        save()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    closeButton
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
        .alert(
            resultMessage ?? "",
            isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )
        ) {
            Button("OK") { resultMessage = nil }
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.15), in: Circle())
        }
        .accessibilityLabel("閉じる")
    }

    private func save() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                performSave()
            default:
                DispatchQueue.main.async {
                    resultMessage = "写真ライブラリへのアクセスが許可されていません。設定アプリから許可してください。"
                }
            }
        }
    }

    private func performSave() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    resultMessage = "写真アプリに保存しました"
                } else {
                    resultMessage = "保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                }
            }
        }
    }
}

#Preview {
    DeckImagePreviewModal(image: UIImage(systemName: "photo") ?? UIImage(), onClose: {})
}

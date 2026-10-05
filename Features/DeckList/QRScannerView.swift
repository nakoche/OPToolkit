//
//  QRScannerView.swift
//  OPToolkit
//
//  デッキのQRコードを読み込む画面。
//  - 「画像から」（デフォルト）: 写真アプリの画像からQRコードを読み取る（PhotosPicker）。
//    デッキ画像（QR付き）をそのまま選べる。写真ライブラリへの権限は不要。
//  - 「カメラ」: AVFoundationでQRコードを読み取る。Info.plistに NSCameraUsageDescription が必要。
//    画面中央の枠の中だけを読み取り対象にし、枠の外は暗くして、どこに合わせればよいかを示す。
//  カメラは「カメラ」に切り替えたときだけ起動する。
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case image = "画像から"
        case camera = "カメラ"

        var id: String { rawValue }
    }

    @State private var mode: Mode = .image
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .image: imageImportView
                case .camera: cameraView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .principal) {
                    Picker("読み込み方法", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            // カメラ画面ではナビゲーションバーを透過して暗い配色にする
            .toolbarBackground(mode == .camera ? .hidden : .automatic, for: .navigationBar)
            .toolbarColorScheme(mode == .camera ? .dark : nil, for: .navigationBar)
        }
    }

    // MARK: - 画像から読み込み

    private var imageImportView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("QRコード付きのデッキ画像を\n写真から選んでください")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView("読み取り中…")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await handlePickedItem(item) }
        }
    }

    @MainActor
    private func handlePickedItem(_ item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        // 同じ写真をもう一度選んでも反応するよう、終わったら選択状態を戻す
        defer {
            isProcessing = false
            selectedItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "画像を読み込めませんでした"
            return
        }
        guard let string = await QRImageDecoder.decode(imageData: data) else {
            errorMessage = "画像からQRコードを検出できませんでした。QRコードが写っている画像を選んでください"
            return
        }
        onScan(string)
    }

    // MARK: - カメラ

    private var cameraView: some View {
        QRScannerRepresentable(onScan: onScan)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("QRコードを枠の中に合わせてください")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
    }
}

/// UIKitのAVCaptureSessionをラップするView
private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    // 読み取り枠まわりの表示（枠の外を暗くする・3x3のグリッド・四隅の目印）
    private let dimLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()

    /// 読み取り枠（画面中央の正方形）。表示と読み取り範囲(rectOfInterest)の両方でこれを使う。
    private var scanRect: CGRect {
        let side = min(view.bounds.width, view.bounds.height) * 0.7
        return CGRect(
            x: (view.bounds.width - side) / 2,
            y: (view.bounds.height - side) / 2,
            width: side,
            height: side
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        setupOverlayLayers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning {
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async { [weak self] in
                    // セッション開始後に読み取り範囲を確定させる
                    self?.updateRectOfInterest()
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateOverlay()
        updateRectOfInterest()
    }

    // MARK: - セッション

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            // TODO: カメラが使えない場合（シミュレータ等）のエラー表示
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }

    /// 読み取りの対象を枠の中だけに絞る（枠の外のQRコードは読み取らない）
    private func updateRectOfInterest() {
        guard let previewLayer else { return }
        metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
    }

    // MARK: - 読み取り枠の表示

    private func setupOverlayLayers() {
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor

        gridLayer.fillColor = nil
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridLayer.lineWidth = 1

        cornerLayer.fillColor = nil
        cornerLayer.strokeColor = UIColor.white.cgColor
        cornerLayer.lineWidth = 4
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round

        [dimLayer, gridLayer, cornerLayer].forEach { view.layer.addSublayer($0) }
    }

    private func updateOverlay() {
        let rect = scanRect

        // 画面全体から枠の内側をくり抜いて、枠の外だけを暗くする
        let dimPath = UIBezierPath(rect: view.bounds)
        dimPath.append(UIBezierPath(rect: rect))

        // 3x3のグリッド（枠を3分割する線）
        let gridPath = UIBezierPath()
        for i in 1...2 {
            let fraction = CGFloat(i) / 3
            let x = rect.minX + rect.width * fraction
            let y = rect.minY + rect.height * fraction
            gridPath.move(to: CGPoint(x: x, y: rect.minY))
            gridPath.addLine(to: CGPoint(x: x, y: rect.maxY))
            gridPath.move(to: CGPoint(x: rect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        // 四隅の目印
        let length: CGFloat = 28
        let cornerPath = UIBezierPath()
        cornerPath.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        cornerPath.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        cornerPath.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        cornerPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        cornerPath.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        cornerPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        // 画面の回転などでアニメーションがかからないようにする
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.frame = view.bounds
        dimLayer.path = dimPath.cgPath
        gridLayer.path = gridPath.cgPath
        cornerLayer.path = cornerPath.cgPath
        CATransaction.commit()
    }

    // MARK: - 読み取り結果

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let stringValue = object.stringValue else { return }

        didScan = true
        onScan?(stringValue)
    }
}

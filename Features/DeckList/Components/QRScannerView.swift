//
//  QRScannerView.swift
//  OPToolkit
//
//  カメラでQRコードを読み取る画面。AVFoundation標準機能のみで実装しており、
//  外部ライブラリは不要。Info.plistに NSCameraUsageDescription の追加が必要。
//

import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            QRScannerRepresentable(onScan: onScan)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Text("デッキのQRコードを枠内に写してください")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 16)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル", action: onCancel)
                            .tint(.white)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
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
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            // TODO: カメラが使えない場合（シミュレータ等）のエラー表示
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.layer.bounds
    }

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

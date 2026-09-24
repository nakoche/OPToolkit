//
//  ShareSheet.swift
//  OPToolkit
//
//  生成したデッキ画像などを共有するための、UIActivityViewControllerのSwiftUIラッパー。
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

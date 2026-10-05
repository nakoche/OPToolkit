//
//  BackSwipeInterceptor.swift
//  OPToolkit
//
//  画面の左端から右へスワイプして戻る操作（インタラクティブな戻り）を、
//  「変更があるときだけ」止めて、確認を出すためのヘルパー。
//
//  SwiftUIにはスワイプでの戻りを途中で止めるAPIが無いので、NavigationStackの裏側にある
//  UINavigationControllerの戻りジェスチャーのdelegateを、この画面が表示されている間だけ差し替える。
//  カスタムの戻るボタン（.navigationBarBackButtonHidden(true)）を使うと標準のスワイプ戻りが
//  無効になるため、その復活も兼ねている。
//
//  使い方: .background { BackSwipeInterceptor(isEnabled: 変更あり, onIntercept: { 確認を出す }) }
//

import SwiftUI
import UIKit

struct BackSwipeInterceptor: UIViewControllerRepresentable {
    /// trueの間は、スワイプでの戻りを止めて onIntercept を呼ぶ
    var isEnabled: Bool
    var onIntercept: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.isEnabled = isEnabled
        controller.onIntercept = onIntercept
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onIntercept = onIntercept
        controller.isEnabled = isEnabled
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        var onIntercept: (() -> Void)?
        var isEnabled = false {
            didSet { updateContentPopGesture() }
        }

        private weak var previousEdgeDelegate: UIGestureRecognizerDelegate?

        /// iOS 26以降にある「画面のどこからでも戻れる」ジェスチャー。
        /// SDKのバージョンに依存しないよう、存在を実行時に確認して取り出す。
        private var contentPopRecognizer: UIGestureRecognizer? {
            guard let navigationController,
                  navigationController.responds(to: NSSelectorFromString("interactiveContentPopGestureRecognizer"))
            else { return nil }
            return navigationController.value(forKey: "interactiveContentPopGestureRecognizer") as? UIGestureRecognizer
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if let recognizer = navigationController?.interactivePopGestureRecognizer, recognizer.delegate !== self {
                previousEdgeDelegate = recognizer.delegate
                recognizer.delegate = self
            }
            updateContentPopGesture()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // 他の画面に影響しないよう、元の状態に戻す
            if let recognizer = navigationController?.interactivePopGestureRecognizer, recognizer.delegate === self {
                recognizer.delegate = previousEdgeDelegate
            }
            contentPopRecognizer?.isEnabled = true
        }

        /// 変更がある間は、画面の中ほどからの戻りスワイプ（iOS 26）を無効にする。
        /// 画面の左端からのスワイプは、下のgestureRecognizerShouldBeginで止めて確認を出す。
        private func updateContentPopGesture() {
            contentPopRecognizer?.isEnabled = !isEnabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // ルート画面では戻れないので始めない
            guard (navigationController?.viewControllers.count ?? 0) > 1 else { return false }

            if isEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.onIntercept?()
                }
                return false
            }
            return true
        }
    }
}

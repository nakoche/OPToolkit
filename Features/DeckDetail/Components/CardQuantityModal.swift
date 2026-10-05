//
//  CardQuantityModal.swift
//  OPToolkit
//
//  デッキカード選択画面でカードをタップした時に出るモーダル。
//  -ボタン／数字（最大4）／+ボタン／デッキに追加ボタン（0のときは押せない）。
//  CardDetailModalと同じ「その場にふっと浮かび上がる」全画面オーバーレイ方式。
//

import SwiftUI

struct CardQuantityModal: View {
    let card: Card
    let initialQuantity: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    @State private var quantity: Int

    private let maxQuantity = Deck.maxCopiesPerCard

    init(card: Card, initialQuantity: Int, onConfirm: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.card = card
        self.initialQuantity = initialQuantity
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _quantity = State(initialValue: initialQuantity)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 24) {
                Spacer()

                cardImage
                    .padding(.horizontal, 60)

                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                stepper

                Button {
                    onConfirm(quantity)
                } label: {
                    Text(confirmTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRemoving ? .red : .accentColor)
                .disabled(!canConfirm)
                .padding(.horizontal, 40)

                // 下側にSpacerを置かないことで、バツボタン以外の全体がバツボタンの真上に寄る
                // （「デッキに追加」ボタンとバツボタンの間隔は、VStackのspacingの24pt）
                closeButton
                    .padding(.bottom, 24)
            }
        }
    }

    /// 既にデッキに入っているカードを0枚にしようとしている状態（＝デッキから外す）
    private var isRemoving: Bool {
        quantity == 0 && initialQuantity > 0
    }

    private var confirmTitle: String {
        isRemoving ? "デッキから外す" : "デッキに追加"
    }

    /// 0枚のままでも、元々デッキに入っていれば「外す」ために押せる。
    /// 元々入っておらず0枚のままなら、何も変わらないので押せない。
    private var canConfirm: Bool {
        quantity > 0 || initialQuantity > 0
    }

    private var cardImage: some View {
        CardThumbnailImage(card: card, cornerRadius: 12)
    }

    private var stepper: some View {
        HStack(spacing: 24) {
            Button {
                quantity = max(0, quantity - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .disabled(quantity <= 0)

            Text("\(quantity)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 44)

            Button {
                quantity = min(maxQuantity, quantity + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .disabled(quantity >= maxQuantity)
        }
    }

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.15), in: Circle())
        }
        .accessibilityLabel("閉じる")
    }
}

#Preview {
    CardQuantityModal(card: .sampleZoro, initialQuantity: 2, onConfirm: { _ in }, onCancel: {})
}

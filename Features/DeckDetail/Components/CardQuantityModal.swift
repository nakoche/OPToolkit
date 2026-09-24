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

    private let maxQuantity = 4

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
                    Text("デッキに追加")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(quantity <= 0)
                .padding(.horizontal, 40)

                Spacer()

                closeButton
                    .padding(.bottom, 24)
            }
        }
    }

    private var cardImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.06))
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                // TODO: 実画像に差し替え（card.imageName）
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.6))
            }
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

//
//  CardBackImage.swift
//  OPToolkit
//
//  カードの裏面（など、アプリに同梱した画像）を、CardThumbnailImageと同じ
//  2.5:3.5の枠・角丸で表示する共通部品。
//  サイズは呼び出し側で .frame(width:) を指定する（高さは比率から決まる）。
//  imageName に "DonFront" / "DonBack" を渡せば、ドン!!カードの表面・裏面も同じ枠で表示できる。
//

import SwiftUI

struct CardBackImage: View {
    /// Assets.xcassets のImage Set名（CardBack / DonFront / DonBack）
    var imageName: String = "CardBack"
    var cornerRadius: CGFloat = 6

    var body: some View {
        Color(uiColor: .systemGray5)
            .aspectRatio(2.5 / 3.5, contentMode: .fit)
            .overlay {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    HStack {
        CardBackImage().frame(width: 60)
        CardBackImage(imageName: "DonBack").frame(width: 60)
        CardBackImage(imageName: "DonFront").frame(width: 60)
    }
    .padding()
}

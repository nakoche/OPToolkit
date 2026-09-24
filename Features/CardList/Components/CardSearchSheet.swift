//
//  CardSearchSheet.swift
//  OPToolkit
//
//  右下のフィルタボタンから開く、フィルタ・並び替えをまとめたシート。
//  カード名・番号の検索はCardListView側の.searchable（画面上部）に移動したため、
//  ここでは扱わない。
//  Formは使わず、ScrollView + 自前レイアウトで組んでいる
//  （UITableView由来のタップ/スクロール判定待ちを避けるため）。
//
//  値は一旦このシート内のローカル状態(CardSearchCriteria)として編集し、
//  「検索」を押したときだけ呼び出し元（CardListViewModel）に反映する。
//  「キャンセル」を押した場合はローカル状態ごと破棄されるだけなので、
//  途中まで変更したフィルタは元に戻る。
//

import SwiftUI

struct CardSearchSheet: View {
    @State private var criteria: CardSearchCriteria

    /// 非nilの場合、色フィルタをこの色だけに固定し、変更不可にする（デッキカード選択画面用）
    let lockedColors: Set<CardColor>?

    let onSearch: (CardSearchCriteria) -> Void
    let onCancel: () -> Void

    @FocusState private var isFeatureFieldFocused: Bool

    init(
        criteria: CardSearchCriteria,
        lockedColors: Set<CardColor>? = nil,
        onSearch: @escaping (CardSearchCriteria) -> Void,
        onCancel: @escaping () -> Void
    ) {
        var initial = criteria
        if let lockedColors {
            initial.selectedColors = lockedColors
        }
        _criteria = State(initialValue: initial)
        self.lockedColors = lockedColors
        self.onSearch = onSearch
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("色") {
                        LazyVGrid(columns: gridColumns(6), spacing: 8) {
                            ForEach(CardColor.allCases) { color in
                                FilterChip(
                                    label: color.rawValue,
                                    tint: color.tint,
                                    isSelected: criteria.selectedColors.contains(color)
                                ) {
                                    toggle(color, in: &criteria.selectedColors)
                                }
                                .disabled(lockedColors != nil)
                                .opacity(lockedColors != nil ? 0.7 : 1)
                            }
                        }
                    }

                    section("種別") {
                        LazyVGrid(columns: gridColumns(4), spacing: 8) {
                            ForEach(CardType.allCases) { type in
                                FilterChip(
                                    label: type.rawValue,
                                    isSelected: criteria.selectedTypes.contains(type)
                                ) {
                                    toggle(type, in: &criteria.selectedTypes)
                                }
                            }
                        }
                    }

                    section("特徴") {
                        featureField
                    }

                    section("コスト") {
                        LazyVGrid(columns: gridColumns(6), spacing: 8) {
                            ForEach(CostOption.all) { option in
                                FilterChip(
                                    label: option.label,
                                    isSelected: criteria.selectedCosts.contains(option)
                                ) {
                                    toggle(option, in: &criteria.selectedCosts)
                                }
                            }
                        }
                    }

                    section("パワー*1000") {
                        LazyVGrid(columns: gridColumns(7), spacing: 8) {
                            ForEach(0...13, id: \.self) { power in
                                FilterChip(
                                    label: "\(power)",
                                    isSelected: criteria.selectedPowers.contains(power)
                                ) {
                                    toggle(power, in: &criteria.selectedPowers)
                                }
                            }
                        }
                    }

                    section("属性") {
                        LazyVGrid(columns: gridColumns(5), spacing: 8) {
                            ForEach(CardAttribute.allCases) { attribute in
                                FilterChip(
                                    label: attribute.rawValue,
                                    isSelected: criteria.selectedAttributes.contains(attribute)
                                ) {
                                    toggle(attribute, in: &criteria.selectedAttributes)
                                }
                            }
                        }
                    }

                    section("カウンター") {
                        LazyVGrid(columns: gridColumns(3), spacing: 8) {
                            ForEach(CounterOption.allCases) { option in
                                FilterChip(
                                    label: option.rawValue,
                                    isSelected: criteria.selectedCounters.contains(option)
                                ) {
                                    toggle(option, in: &criteria.selectedCounters)
                                }
                            }
                        }
                    }

                    section("レアリティ") {
                        // 常に1行（7列固定）で表示する。SECのような3文字ラベルは
                        // FilterChip側でminimumScaleFactorを使って自動縮小させる。
                        LazyVGrid(columns: gridColumns(7), spacing: 6) {
                            ForEach(CardRarity.allCases) { rarity in
                                FilterChip(
                                    label: rarity.rawValue,
                                    isSelected: criteria.selectedRarities.contains(rarity)
                                ) {
                                    toggle(rarity, in: &criteria.selectedRarities)
                                }
                            }
                        }
                    }

                    section("ブロックアイコン") {
                        LazyVGrid(columns: gridColumns(6), spacing: 8) {
                            ForEach(CardBlockIcon.allCases) { block in
                                FilterChip(
                                    label: block.rawValue,
                                    isSelected: criteria.selectedBlockIcons.contains(block)
                                ) {
                                    toggle(block, in: &criteria.selectedBlockIcons)
                                }
                            }
                        }
                    }

                    section("並び替え") {
                        VStack(spacing: 12) {
                            Picker("並び替えの基準", selection: $criteria.sortKey) {
                                ForEach(CardSortKey.allCases) { key in
                                    Text(key.rawValue).tag(key)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker("順序", selection: $criteria.sortDirection) {
                                Label("昇順", systemImage: "arrow.up").tag(SortDirection.ascending)
                                Label("降順", systemImage: "arrow.down").tag(SortDirection.descending)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("検索・絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("リセット") {
                        var reset = CardSearchCriteria()
                        if let lockedColors {
                            reset.selectedColors = lockedColors
                        }
                        criteria = reset
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: - セクション共通レイアウト

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func gridColumns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var featureField: some View {
        HStack {
            Image(systemName: "tag")
                .foregroundStyle(.secondary)
            TextField("特徴で検索（例: 麦わらの一味）", text: $criteria.featureQuery)
                .focused($isFeatureFieldFocused)
            if !criteria.featureQuery.isEmpty {
                Button {
                    criteria.featureQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
            } label: {
                Text("キャンセル")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)

            Button {
                var result = criteria
                if let lockedColors {
                    result.selectedColors = lockedColors
                }
                onSearch(result)
            } label: {
                Text("検索")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.bar)
    }

    // MARK: - Set操作の共通ヘルパー

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

#Preview {
    CardSearchSheet(
        criteria: CardSearchCriteria(),
        onSearch: { _ in },
        onCancel: {}
    )
}

import SwiftUI

/// One filter dimension (galleries, studios, tags or cast) as a titled chip cloud.
struct FilterSectionView: View {
    enum Mode {
        /// Selected values are allowed; everything starts selected.
        case include
        /// Every selected value must be present; nothing starts selected.
        case require
    }

    struct Item: Identifiable {
        let value: String
        let label: String
        var id: String { value }
    }

    let title: String
    let explanation: String
    let mode: Mode
    let allItems: [Item]
    let visibleItems: [Item]
    let selection: Set<String>
    let emptyMessage: String
    let onChange: (Set<String>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header

            if allItems.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else if visibleItems.isEmpty {
                Text("No matches")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: Spacing.sm - 2, lineSpacing: Spacing.sm - 2) {
                    ForEach(visibleItems) { item in
                        FilterChip(title: item.label, isSelected: selection.contains(item.value)) {
                            toggle(item.value)
                        }
                        .contextMenu { contextMenu(for: item) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(summary)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.lg)

            if !allItems.isEmpty {
                HStack(spacing: Spacing.md) {
                    switch mode {
                    case .include:
                        Button("Include All") { onChange(Set(allItems.map(\.value))) }
                            .disabled(selection.count == allItems.count)
                        Button("Include None") { onChange([]) }
                            .disabled(selection.isEmpty)
                    case .require:
                        Button("Clear") { onChange([]) }
                            .disabled(selection.isEmpty)
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    private var summary: String {
        switch mode {
        case .include:
            selection.count == allItems.count ? "All \(allItems.count)" : "\(selection.count) of \(allItems.count)"
        case .require:
            selection.isEmpty ? "Any" : "\(selection.count) required"
        }
    }

    private func toggle(_ value: String) {
        var updated = selection
        if updated.contains(value) {
            updated.remove(value)
        } else {
            updated.insert(value)
        }
        onChange(updated)
    }

    @ViewBuilder
    private func contextMenu(for item: Item) -> some View {
        switch mode {
        case .include:
            Button("Include Only “\(item.label)”") { onChange([item.value]) }
            Button("Include All Except “\(item.label)”") {
                onChange(Set(allItems.map(\.value)).subtracting([item.value]))
            }
        case .require:
            Button("Require Only “\(item.label)”") { onChange([item.value]) }
        }
    }
}

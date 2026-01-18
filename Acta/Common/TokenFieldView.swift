import SwiftUI

struct TokenFieldView: View {
    @Binding var tokens: [String]
    var placeholder: String
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $input)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                input = commitInput(input, keepRemainder: false)
                DispatchQueue.main.async {
                    input = ""
                }
            }
            .onChange(of: input) { _, newValue in
                if newValue.contains("\n") {
                    input = commitInput(newValue, keepRemainder: true)
                }
            }

            WrappingTagLayout(
                alignment: .leading,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            ) {
                ForEach(tokens, id: \.self) { token in
                    TokenFieldTagView(title: token) {
                        removeToken(token)
                    }
                }
            }
        }
    }

    private func commitInput(_ raw: String, keepRemainder: Bool) -> String {
        let rawParts = raw.split(whereSeparator: { $0.isNewline })
        guard !rawParts.isEmpty else { return raw }
        var parts = rawParts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var remainder = ""

        if keepRemainder, let last = parts.last, !raw.hasSuffix("\n") {
            remainder = last
            parts.removeLast()
        }

        if !parts.isEmpty {
            tokens.append(contentsOf: parts)
        }
        return remainder
    }

    private func removeToken(_ token: String) {
        tokens.removeAll { $0.caseInsensitiveCompare(token) == .orderedSame }
    }
}

private struct TokenFieldTagView: View {
    let title: String
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}

private struct WrappingTagLayout: Layout {
    var alignment: Alignment = .leading
    var horizontalSpacing: CGFloat?
    var verticalSpacing: CGFloat?

    init(
        alignment: Alignment = .leading,
        horizontalSpacing: CGFloat? = nil,
        verticalSpacing: CGFloat? = nil
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }

    struct Cache {
        var minSize: CGSize
        var rows: (Int, [Row])?
    }

    struct Row {
        var elements: [(index: Int, size: CGSize, xOffset: CGFloat)] = []
        var yOffset: CGFloat = .zero
        var width: CGFloat = .zero
        var height: CGFloat = .zero
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(minSize: minSize(subviews: subviews))
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.minSize = minSize(subviews: subviews)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews, cache: &cache)
        let width = proposal.width ?? rows.map(\.width).reduce(.zero, max)
        let height = rows.last.map { $0.yOffset + $0.height } ?? .zero
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews, cache: &cache)
        let anchor = UnitPoint(alignment)

        for row in rows {
            for element in row.elements {
                let xCorrection = anchor.x * (bounds.width - row.width)
                let yCorrection = anchor.y * (row.height - element.size.height)
                let point = CGPoint(
                    x: bounds.minX + element.xOffset + xCorrection,
                    y: bounds.minY + row.yOffset + yCorrection
                )
                subviews[element.index].place(
                    at: point,
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
            }
        }
    }

    private func arrangeRows(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> [Row] {
        let minSize = cache.minSize
        let resolved = proposal.replacingUnspecifiedDimensions(
            by: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        guard minSize.width <= resolved.width || minSize.height <= resolved.height else {
            return []
        }

        let proposedSize = ProposedViewSize(resolved)
        let sizes = subviews.map { $0.sizeThatFits(proposedSize) }
        let hash = computeHash(proposal: resolved, sizes: sizes)
        if let (oldHash, oldRows) = cache.rows, oldHash == hash {
            return oldRows
        }

        var currentX: CGFloat = .zero
        var currentRow = Row()
        var rows: [Row] = []

        for index in subviews.indices {
            var spacing: CGFloat = .zero
            if let previousIndex = currentRow.elements.last?.index {
                spacing = horizontalSpacing(
                    subviews[previousIndex],
                    subviews[index]
                )
            }

            let size = sizes[index]
            if currentX + size.width + spacing > resolved.width,
               !currentRow.elements.isEmpty {
                currentRow.width = currentX
                rows.append(currentRow)
                currentRow = Row()
                spacing = .zero
                currentX = .zero
            }

            currentRow.elements.append((index, size, currentX + spacing))
            currentX += size.width + spacing
        }

        currentRow.width = currentX
        rows.append(currentRow)

        var currentY: CGFloat = .zero
        var previousMaxHeightIndex: Int?

        for index in rows.indices {
            let maxHeightIndex = rows[index].elements
                .max { $0.size.height < $1.size.height }?
                .index

            guard let maxHeightIndex else { continue }
            let size = sizes[maxHeightIndex]

            var spacing: CGFloat = .zero
            if let previousMaxHeightIndex {
                spacing = verticalSpacing(
                    subviews[previousMaxHeightIndex],
                    subviews[maxHeightIndex]
                )
            }

            rows[index].yOffset = currentY + spacing
            currentY += size.height + spacing
            rows[index].height = size.height
            previousMaxHeightIndex = maxHeightIndex
        }

        cache.rows = (hash, rows)
        return rows
    }

    private func minSize(subviews: Subviews) -> CGSize {
        subviews
            .map { $0.sizeThatFits(.zero) }
            .reduce(.zero) { current, next in
                CGSize(
                    width: max(current.width, next.width),
                    height: max(current.height, next.height)
                )
            }
    }

    private func horizontalSpacing(_ lhs: LayoutSubview, _ rhs: LayoutSubview) -> CGFloat {
        if let horizontalSpacing { return horizontalSpacing }
        return lhs.spacing.distance(to: rhs.spacing, along: .horizontal)
    }

    private func verticalSpacing(_ lhs: LayoutSubview, _ rhs: LayoutSubview) -> CGFloat {
        if let verticalSpacing { return verticalSpacing }
        return lhs.spacing.distance(to: rhs.spacing, along: .vertical)
    }

    private func computeHash(proposal: CGSize, sizes: [CGSize]) -> Int {
        var hasher = Hasher()
        hasher.combine(proposal.width)
        hasher.combine(proposal.height)
        for size in sizes {
            hasher.combine(size.width)
            hasher.combine(size.height)
        }
        return hasher.finalize()
    }
}

private extension UnitPoint {
    init(_ alignment: Alignment) {
        switch alignment {
        case .leading:
            self = .leading
        case .topLeading:
            self = .topLeading
        case .top:
            self = .top
        case .topTrailing:
            self = .topTrailing
        case .trailing:
            self = .trailing
        case .bottomTrailing:
            self = .bottomTrailing
        case .bottom:
            self = .bottom
        case .bottomLeading:
            self = .bottomLeading
        default:
            self = .center
        }
    }
}

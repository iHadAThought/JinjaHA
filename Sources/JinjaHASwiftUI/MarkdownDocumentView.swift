import Foundation
import SwiftUI

/// Lightweight markdown presenter with GFM table support.
///
/// Apple's `AttributedString(markdown:)` (CommonMark) does **not** support pipe
/// tables and collapses them into a single run. This view splits the document into
/// blocks and renders tables with SwiftUI `Grid`.
public struct MarkdownDocumentView: View {
    public let source: String

    public init(source: String) {
        self.source = source
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlockParser.parse(source).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .markdown(text):
                    Text(attributed(text))
                case let .table(table):
                    markdownTable(table)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributed(_ text: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .full)
        ) {
            return parsed
        }
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(text)
    }

    @ViewBuilder
    private func markdownTable(_ table: MarkdownTable) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(attributedInline(cell))
                            .fontWeight(rowIndex == 0 ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if rowIndex == 0 {
                    Divider()
                        .gridCellColumns(max(table.columnCount, 1))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func attributedInline(_ text: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(text)
    }
}

enum MarkdownBlock: Equatable {
    case markdown(String)
    case table(MarkdownTable)
}

struct MarkdownTable: Equatable {
    var rows: [[String]]

    var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }
}

enum MarkdownBlockParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var markdownBuffer: [String] = []
        var index = 0

        func flushMarkdown() {
            let text = markdownBuffer.joined(separator: "\n").trimmingCharacters(in: .newlines)
            markdownBuffer.removeAll(keepingCapacity: true)
            guard !text.isEmpty else { return }
            blocks.append(.markdown(text))
        }

        while index < lines.count {
            if isTableRow(lines[index]) {
                var tableLines: [String] = []
                while index < lines.count, isTableRow(lines[index]) {
                    tableLines.append(lines[index])
                    index += 1
                }
                if let table = parseTable(tableLines) {
                    flushMarkdown()
                    blocks.append(.table(table))
                } else {
                    markdownBuffer.append(contentsOf: tableLines)
                }
                continue
            }
            markdownBuffer.append(lines[index])
            index += 1
        }
        flushMarkdown()
        return blocks
    }

    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        // Allow leading/trailing pipes; reject obvious non-rows.
        return trimmed.contains(where: { !$0.isWhitespace && $0 != "|" && $0 != "-" && $0 != ":" })
            || isSeparatorRow(trimmed)
    }

    private static func isSeparatorRow(_ trimmed: String) -> Bool {
        let cells = splitCells(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.replacingOccurrences(of: " ", with: "")
            return !compact.isEmpty && compact.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseTable(_ lines: [String]) -> MarkdownTable? {
        guard lines.count >= 2 else { return nil }
        let rows = lines.map(splitCells)
        // Drop GFM separator row(s).
        let dataRows = rows.filter { row in
            !row.allSatisfy { cell in
                let compact = cell.replacingOccurrences(of: " ", with: "")
                return !compact.isEmpty && compact.allSatisfy { $0 == "-" || $0 == ":" }
            }
        }
        guard dataRows.count >= 1 else { return nil }
        let width = dataRows.map(\.count).max() ?? 0
        let normalized = dataRows.map { row -> [String] in
            if row.count == width { return row }
            if row.count > width { return Array(row.prefix(width)) }
            return row + Array(repeating: "", count: width - row.count)
        }
        return MarkdownTable(rows: normalized)
    }

    private static func splitCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

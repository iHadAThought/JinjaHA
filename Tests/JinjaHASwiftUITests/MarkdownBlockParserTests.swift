import XCTest
@testable import JinjaHASwiftUI

final class MarkdownBlockParserTests: XCTestCase {
    func testParsesHeadingAndGFMTable() {
        let source = """
        ### Kitchen status

        | Entity | State |
        | --- | --- |
        | Outdoor | 21.5 °C |
        | Light | on |
        | Door | closed |
        """
        let blocks = MarkdownBlockParser.parse(source)
        XCTAssertEqual(blocks.count, 2)
        guard case let .markdown(heading) = blocks[0] else {
            return XCTFail("Expected markdown heading block")
        }
        XCTAssertTrue(heading.contains("Kitchen status"))
        guard case let .table(table) = blocks[1] else {
            return XCTFail("Expected table block")
        }
        XCTAssertEqual(table.rows.count, 4) // header + 3 data (separator dropped)
        XCTAssertEqual(table.rows[0], ["Entity", "State"])
        XCTAssertEqual(table.rows[1], ["Outdoor", "21.5 °C"])
        XCTAssertEqual(table.rows[3], ["Door", "closed"])
    }

    func testAttributedStringFullCollapsesTables_documentedLimitation() {
        // Guardrail: Foundation markdown must not be used alone for GFM tables.
        let md = """
        ### Kitchen status

        | Entity | State |
        | --- | --- |
        | Outdoor | 21.5 °C |
        """
        let collapsed = (try? AttributedString(
            markdown: md,
            options: .init(interpretedSyntax: .full)
        )).map { String($0.characters) } ?? ""
        XCTAssertFalse(collapsed.contains("|"), "Foundation markdown strips table pipes")
        XCTAssertTrue(collapsed.contains("EntityState") || !collapsed.contains("\n"))
    }
}

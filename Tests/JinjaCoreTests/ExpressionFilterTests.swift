import JinjaCore
import XCTest

final class ExpressionFilterTests: XCTestCase {
    func testCommonFilters() throws {
        let template = try Template("""
        {{ 'Hi' | upper }}|{{ 'Hi' | lower }}|{{ '  x  ' | trim }}|{{ [1,2,3] | length }}|{{ missing | default('d') }}
        """)
        XCTAssertEqual(try template.render([:]), "HI|hi|x|3|d")
    }

    func testJoinFirstLast() throws {
        let template = try Template("{{ ['a','b','c'] | join('-') }}|{{ [9,8] | first }}|{{ [9,8] | last }}")
        XCTAssertEqual(try template.render([:]), "a-b-c|9|8")
    }

    func testArithmeticAndComparisons() throws {
        let template = try Template("{{ 1 + 2 * 3 }}|{{ 10 // 3 }}|{{ 2 ** 3 }}|{{ 5 > 3 }}")
        XCTAssertEqual(try template.render([:]), "7|3|8|true")
    }

    func testTernaryExpression() throws {
        let template = try Template("{{ 'yes' if true else 'no' }}|{{ 'yes' if false else 'no' }}")
        XCTAssertEqual(try template.render([:]), "yes|no")
    }

    func testDefinedUndefinedTests() throws {
        let template = try Template("{% if x is undefined %}u{% endif %}{% if none is defined %}d{% endif %}")
        XCTAssertEqual(try template.render([:]), "ud")
    }

    func testMacroCall() throws {
        let template = try Template("{% macro greet(name) %}Hi {{ name }}{% endmacro %}{{ greet('Bo') }}")
        XCTAssertEqual(try template.render([:]), "Hi Bo")
    }

    func testSetAndForElse() throws {
        let template = try Template("{% set xs = [] %}{% for x in xs %}{{ x }}{% else %}empty{% endfor %}")
        XCTAssertEqual(try template.render([:]), "empty")
    }

    func testLoopIndex() throws {
        let template = try Template("{% for i in [10,20] %}{{ loop.index0 }}:{{ i }};{% endfor %}")
        XCTAssertEqual(try template.render([:]), "0:10;1:20;")
    }
}

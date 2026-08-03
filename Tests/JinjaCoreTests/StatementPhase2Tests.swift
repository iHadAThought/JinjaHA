import JinjaCore
import XCTest

final class StatementPhase2Tests: XCTestCase {
    func testRawBlockLeavesJinjaUninterpreted() throws {
        let template = try Template("A{% raw %}{{ not_a_var }}{% if true %}X{% endif %}{% endraw %}B")
        XCTAssertEqual(try template.render([:]), "A{{ not_a_var }}{% if true %}X{% endif %}B")
    }

    func testWithScopesAssignments() throws {
        let template = try Template("{% with x=1, y=2 %}{{ x }}-{{ y }}{% endwith %}/{{ x }}")
        XCTAssertEqual(try template.render([:]), "1-2/")
    }

    func testWithEmptyThenSetInside() throws {
        let template = try Template("{% with %}{% set z = 'in' %}{{ z }}{% endwith %}")
        XCTAssertEqual(try template.render([:]), "in")
    }

    func testIncludeViaAllowlistLoader() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "part.j2": "PART:{{ name }}",
        ])
        let template = try Template("{% include 'part.j2' %}")
        let output = try template.render(["name": "Ada"], environment: env)
        XCTAssertEqual(output, "PART:Ada")
    }

    func testIncludeIgnoreMissing() throws {
        let env = Environment()
        let template = try Template("X{% include 'missing.j2' ignore missing %}Y")
        XCTAssertEqual(try template.render([:], environment: env), "XY")
    }

    func testIncludeWithoutContext() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "part.j2": "{{ name }}",
        ])
        let template = try Template("{% include 'part.j2' without context %}")
        let output = try template.render(["name": "hidden"], environment: env)
        XCTAssertEqual(output, "")
    }

    func testIncludeDenyAllFails() {
        let env = Environment()
        let template = try! Template("{% include 'x.j2' %}")
        XCTAssertThrowsError(try template.render([:], environment: env))
    }

    func testExtendsAndBlockOverride() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "base.j2": "BEGIN-{% block content %}BASE{% endblock %}-END",
        ])
        let template = try Template("""
        {% extends 'base.j2' %}
        {% block content %}CHILD{% endblock %}
        """)
        XCTAssertEqual(try template.render([:], environment: env), "BEGIN-CHILD-END")
    }

    func testSuperInBlock() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "base.j2": "{% block content %}BASE{% endblock %}",
        ])
        let template = try Template("""
        {% extends 'base.j2' %}
        {% block content %}{{ super() }}+CHILD{% endblock %}
        """)
        XCTAssertEqual(try template.render([:], environment: env), "BASE+CHILD")
    }

    func testImportMacrosAsNamespace() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "lib.j2": "{% macro hello(name) %}Hi {{ name }}{% endmacro %}",
        ])
        let template = try Template("{% import 'lib.j2' as lib %}{{ lib.hello('Ada') }}")
        XCTAssertEqual(try template.render([:], environment: env), "Hi Ada")
    }

    func testFromImportMacro() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "lib.j2": "{% macro hello(name) %}Hi {{ name }}{% endmacro %}",
        ])
        let template = try Template("{% from 'lib.j2' import hello %}{{ hello('Bo') }}")
        XCTAssertEqual(try template.render([:], environment: env), "Hi Bo")
    }

    func testFromImportAlias() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "lib.j2": "{% macro hello(name) %}Hi {{ name }}{% endmacro %}",
        ])
        let template = try Template("{% from 'lib.j2' import hello as hi %}{{ hi('Cy') }}")
        XCTAssertEqual(try template.render([:], environment: env), "Hi Cy")
    }

    func testAdjacentStringLiteralsConcatenate() throws {
        let template = try Template("{{ 'Hi ' 'Ada' }}")
        XCTAssertEqual(try template.render([:]), "Hi Ada")
    }
}

# Compatibility

## Dialect target

| Field | Value |
|-------|--------|
| Jinja dialect | 3.1.x (Pallets) |
| `JinjaCoreInfo.dialectVersion` | 3.1 |
| `JinjaCoreInfo.implementationRevision` | see source |
| Vendored baseline | huggingface/swift-jinja 2.4.2 (owned thereafter) |
| Last reviewed | 2026-08-02 |

> **Cadence:** re-check Pallets Jinja + HA template docs at least every **90 days**, or whenever a security advisory lands.  
> `Scripts/check-compat-notes.sh` fails if “Last reviewed” is older than that window.

## Watch list

| Upstream | What to watch |
|----------|----------------|
| [Pallets Jinja changes](https://jinja.palletsprojects.com/en/stable/changes/) | Syntax, filters/tests, sandbox advisories |
| [HA templating](https://www.home-assistant.io/docs/templating/) | Behavioral notes for templates |
| [HA template functions](https://www.home-assistant.io/template-functions/) | New/changed helpers (`iif`, `states`, floors, …) |

## Intentional differences from CPython Jinja2

See also [`Compatibility/TRACKED_DIFFERENCES.md`](../Compatibility/TRACKED_DIFFERENCES.md) for fixture-oriented notes.

- No Python object model / arbitrary method calls on host objects.
- Sandbox is `AttributePolicy` (default denies `_` prefixed names), not a full Python sandbox.
- HA helpers live in **JinjaHA**, not JinjaCore.
- Implicit concatenation applies to adjacent **string literals** only (`'a' "b"`), not identifiers — so statement modifiers (`as`, `ignore missing`, `without context`) are not swallowed.
- `{% include %}` / `{% extends %}` / import require an explicit `TemplateLoader` (default deny-all).
- Objects may carry an optional `call` hook and `stringRepresentation` (HA `states` dual-use / entity print).
- GFM pipe tables are rendered by `MarkdownDocumentView` (Foundation `AttributedString(markdown:)` collapses them).

## Absorb a future Jinja release

1. Read the Pallets changelog for the new version.
2. Create `Compatibility/jinja-<version>/` (copy README from `jinja-3.1/` if needed).
3. Add **failing** `.jinja` + `.expected.txt` goldens **before** implementing.
4. Implement in **JinjaCore** (lexer/parser/runtime/filters/tests/policy).
5. Bump `JinjaCoreInfo.dialectVersion` and/or `implementationRevision`.
6. Mark rows in [`FEATURES.md`](FEATURES.md); set **Last reviewed** above to today.
7. Run `swift test` and `Scripts/check-compat-notes.sh`.

## Absorb a Home Assistant helper change

1. Read HA template-functions docs for the helper.
2. Add a failing golden under `Compatibility/home-assistant/`.
3. Register via Environment registries in **JinjaHA** only (no lexer hacks).
4. Bump `JinjaHAInfo.homeAssistantHelpersRevision`.
5. Update FEATURES + **Last reviewed**; run tests + compat check.

## Security advisories

When Pallets or HA publish sandbox / attribute / ReDoS-style advisories:

1. Open or extend a Compatibility fixture that reproduces the unsafe pattern (if feasible).
2. Tighten `AttributePolicy` and/or `HATemplateLimits` in the **same** change.
3. Note the advisory ID in the commit message and bump **Last reviewed**.

## Local checks

```bash
# Staleness of this file’s “Last reviewed” (default max age: 90 days)
Scripts/check-compat-notes.sh

# Override window (days)
COMPAT_MAX_AGE_DAYS=60 Scripts/check-compat-notes.sh
```

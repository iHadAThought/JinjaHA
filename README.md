# JinjaHA

Swift library for evaluating **Home Assistant Jinja2** templates on Apple platforms, with an optional SwiftUI presentation layer.

Use it in apps that connect to Home Assistant and render Lovelace dashboards (iOS, tvOS, macOS, watchOS).

The Jinja2 runtime is **owned** as `JinjaCore` (vendored baseline from huggingface/swift-jinja 2.4.2, Apache-2.0 — see `NOTICE`). There is no runtime dependency on huggingface. See [`Docs/COMPAT.md`](Docs/COMPAT.md) and [`Docs/FEATURES.md`](Docs/FEATURES.md).

**Forgejo:** [Brendan/JinjaHA](https://git.ghostnetwork.app/Brendan/JinjaHA)  
**BookStack:** [JinjaHA](https://bookstack.ghostnetwork.app/books/jinjaha)

## Products

| Product | Purpose |
|---------|---------|
| **JinjaCore** | Owned Jinja2 engine (lexer/parser/runtime, registries, loader, attribute policy) |
| **JinjaHA** | HA snapshot helpers + REST `/api/template` client on top of JinjaCore |
| **JinjaHASwiftUI** | `HATemplateText` / `HATemplateMarkdown` with last-good-render semantics |

## Install

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_ORG/JinjaHA.git", from: "0.1.0")
]
```

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "JinjaHA", package: "JinjaHA"),
        .product(name: "JinjaHASwiftUI", package: "JinjaHA"),
    ]
)
```

## Quick start

```swift
import JinjaHA

let snapshot = HAStateSnapshot(
    entities: [
        "sensor.temp": HAEntityState(
            entityID: "sensor.temp",
            state: "22",
            attributes: ["unit_of_measurement": .string("°C")]
        )
    ]
)

let engine = HATemplateEngine(snapshot: snapshot)
let text = try engine.render("{{ states('sensor.temp') }} °C")
// "22 °C"
```

### Render backends

```swift
let local = LocalTemplateRenderer(snapshot: snapshot)
let api = HAAPITemplateRenderer(baseURL: haURL, token: token)
let hybrid = FallbackTemplateRenderer(primary: local, fallback: api)

let rendered = try await hybrid.render(template)
```

### SwiftUI

```swift
import JinjaHASwiftUI

HATemplateMarkdown(
    template: markdownCardContent,
    renderer: local,
    refreshToken: "\(statesRevision)"
)
```

## Feature matrix

| Area | Support |
|------|---------|
| Jinja2 expressions / `if` / `for` / `set` / `macro` / filters / tests | Via swift-jinja |
| `states()`, `is_state`, `is_state_attr`, `state_attr`, `has_value` | Local |
| Dotted `states.domain.object` | Local (prints state; use `.state` / attributes on the object) |
| `\| states` filter | Local (same function as `states(...)`) |
| `expand`, `selectattr` / `rejectattr` / `map` / `join` | Local (`expand` HA-aware; collection filters via Jinja) |
| Areas / devices / floors / labels helpers | Local (from `HAStateSnapshot` registries) |
| Datetime (`now`, `utcnow`, `as_timestamp`, `timedelta`, `time_since`, `today_at`, …) | Local |
| `to_json` / `from_json` | Local |
| `POST /api/template` | `HAAPITemplateRenderer` |
| `{% extends %}` / `{% include %}` / `{% with %}` / `{% raw %}` | Unsupported locally — use API fallback |
| Arbitrary Python methods on HA objects | Unsupported |
| HACS custom Jinja | Unsupported |

## Security

- Template / output byte caps and `range()` size limits (`HATemplateLimits`)
- Optional render timeout
- No filesystem template includes
- API client never logs the bearer token; error bodies scrub the token

## Example

```bash
swift run MinimalRender
```

## Tests

```bash
swift test
```

Optional live parity (compares local vs HA API):

```bash
HA_URL=https://homeassistant.local:8123 HA_TOKEN=xxxxx swift test --filter LiveParityTests
```

## License

Apache 2.0

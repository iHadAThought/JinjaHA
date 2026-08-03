# Setup

## SPM

```swift
dependencies: [
  .package(url: "https://github.com/iHadAThought/JinjaHA.git", from: "0.3.0")
]
```

```swift
.target(name: "MyApp", dependencies: [
  .product(name: "JinjaHA", package: "JinjaHA"),
  .product(name: "JinjaHASwiftUI", package: "JinjaHA"),
])
```

## Local develop

```bash
swift test
swift run MinimalRender
swift run CompareDemo
swift run CompareDemo --export-screenshots Docs/screenshots
Scripts/check-compat-notes.sh
```

## Quick render

```swift
import JinjaHA

let snapshot = HAStateSnapshot(entities: [
  "sensor.temp": HAEntityState(entityID: "sensor.temp", state: "22")
])
let engine = HATemplateEngine(snapshot: snapshot)
let text = try engine.render("{{ states('sensor.temp') }}")
```

## Snapshot cookbook (hybrid apps)

Apps own the HA connection. Fill `HAStateSnapshot`, then render locally with API fallback:

```swift
var snapshot = try HAStateSnapshot.fromStatesJSON(statesData)
snapshot = snapshot
  .merging(entityMeta: try HAStateSnapshot.entityMetaFromRegistryJSON(entityRegistryData))
  .merging(configEntries: try HAStateSnapshot.configEntriesFromJSON(configEntriesData))
  .withHomeLocation(latitude: homeLat, longitude: homeLon)

let local = LocalTemplateRenderer(snapshot: snapshot)
let api = HAAPITemplateRenderer(baseURL: haURL, token: token)
let hybrid = FallbackTemplateRenderer(primary: local, fallback: api)
let rendered = try await hybrid.render(template)
```

### Required snapshot fields by helper

| Helper | Needs |
|--------|--------|
| `states` / `is_state` / … | `entities` |
| `distance` / `closest` | `latitude` + `longitude` (home) |
| `is_hidden_entity` / `integration_entities` / `config_entry_*` | `entityMeta` (+ `configEntries`) |
| `issues` / `issue` | `repairIssues` |
| `{% trans %}` / `state_translated` | `translationStrings` |
| areas / devices / floors / labels | matching registry arrays |

Leave optional tables empty until a board needs them — FallbackTemplateRenderer covers the rest.

# Setup

## SPM

```swift
dependencies: [
  .package(url: "https://git.ghostnetwork.app/Brendan/JinjaHA.git", from: "0.1.0")
]
```

```swift
.target(name: "MyApp", dependencies: [
  .product(name: "JinjaHA", package: "JinjaHA"),
  .product(name: "JinjaHASwiftUI", package: "JinjaHA"),
])
```

Private Forgejo packages may need a netrc / SPM credential helper.

## Local develop

```bash
cd /Users/brendan/Projects/JinjaHA
swift test
swift run MinimalRender
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

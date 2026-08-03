# Setup

## SPM

```swift
dependencies: [
  .package(url: "https://github.com/iHadAThought/JinjaHA.git", from: "0.1.0")
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

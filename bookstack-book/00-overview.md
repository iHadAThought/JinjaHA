# Overview

**JinjaHA** is a Swift package for Apple apps that connect to Home Assistant and need to evaluate Jinja2 templates locally (with optional HA REST `/api/template` fallback) and present results in SwiftUI.

This product is **not** affiliated with or endorsed by the Home Assistant project.

## Products

| Product | Role |
|---------|------|
| **JinjaCore** | Owned Jinja2 engine (lexer/parser/runtime). No huggingface dependency. |
| **JinjaHA** | HA state snapshot + template helpers + API renderer |
| **JinjaHASwiftUI** | `HATemplateText` / `HATemplateMarkdown` with last-good-render semantics |

## Why own the engine?

An earlier spike depended on huggingface/swift-jinja. That capped statements (`{% raw %}`, `{% with %}`, `{% include %}`, …) and clobbered custom globals on env clone. JinjaCore is vendored and maintained in-tree so we can extend it.

## Dialect target

- Pallets Jinja **3.1.x** semantics (see `Docs/COMPAT.md`)
- HA helpers tracked separately (`JinjaHAInfo.homeAssistantHelpersRevision`)

## Repo

- Forgejo: https://git.ghostnetwork.app/Brendan/JinjaHA

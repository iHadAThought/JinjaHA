import Foundation
import JinjaCore
import JinjaHA

enum DemoData {
    static let snapshot: HAStateSnapshot = {
        var snapshot = HAStateSnapshot(
            entities: [
                "sensor.outdoor_temperature": HAEntityState(
                    entityID: "sensor.outdoor_temperature",
                    state: "21.5",
                    attributes: [
                        "unit_of_measurement": .string("°C"),
                        "friendly_name": .string("Outdoor Temperature"),
                    ]
                ),
                "light.kitchen": HAEntityState(
                    entityID: "light.kitchen",
                    state: "on",
                    attributes: [
                        "brightness": .int(180),
                        "friendly_name": .string("Kitchen Light"),
                        "area_id": .string("kitchen"),
                    ]
                ),
                "binary_sensor.front_door": HAEntityState(
                    entityID: "binary_sensor.front_door",
                    state: "off",
                    attributes: ["device_class": .string("door")]
                ),
            ],
            areas: [
                HAArea(areaID: "kitchen", name: "Kitchen", floorID: "downstairs", labels: ["main"]),
            ],
            devices: [
                HADevice(
                    id: "dev_kitchen_light",
                    name: "Kitchen Light Device",
                    areaID: "kitchen",
                    labels: ["lighting"],
                    entities: ["light.kitchen"]
                ),
            ],
            floors: [HAFloor(floorID: "downstairs", name: "Downstairs")],
            labels: [
                HALabel(labelID: "lighting", name: "Lighting"),
                HALabel(labelID: "main", name: "Main"),
            ],
            timeZoneIdentifier: "UTC",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        return snapshot
    }()

    static let engine = HATemplateEngine(snapshot: snapshot)
    static let renderer = LocalTemplateRenderer(engine: engine)

    enum Scenario: String, CaseIterable, Identifiable {
        case states
        case controlFlow
        case markdownCard
        case helpers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .states: return "States"
            case .controlFlow: return "Control flow"
            case .markdownCard: return "Markdown card"
            case .helpers: return "Helpers"
            }
        }

        var usesMarkdown: Bool {
            self == .markdownCard
        }

        var template: String {
            switch self {
            case .states:
                return """
                Outdoor: {{ states('sensor.outdoor_temperature', with_unit=true) }}
                Kitchen: {{ states.light.kitchen }} (brightness {{ state_attr('light.kitchen', 'brightness') }})
                Missing: {{ states('sensor.nope') }}
                """
            case .controlFlow:
                return """
                {% if is_state('light.kitchen', 'on') %}Kitchen light is on{% else %}Kitchen light is off{% endif %}
                Door: {{ is_state('binary_sensor.front_door', 'on') | iif('open', 'closed') }}
                """
            case .markdownCard:
                return """
                ### Kitchen status

                | Entity | State |
                | --- | --- |
                | Outdoor | {{ states('sensor.outdoor_temperature', with_unit=true) }} |
                | Light | {{ states('light.kitchen') }} |
                | Door | {{ is_state('binary_sensor.front_door', 'on') | iif('open', 'closed') }} |
                """
            case .helpers:
                return """
                Slug: {{ slugify('Kitchen Light') }}
                Avg: {{ average(19.5, 21.5, 22.0) }}
                Floor entities: {{ floor_entities('downstairs') | join(', ') }}
                Match light: {{ regex_match('light.kitchen', '^light[.]') }}
                """
            }
        }

        var screenshotFilename: String {
            "compare-\(rawValue).png"
        }
    }

    static func render(_ scenario: Scenario) -> String {
        (try? engine.render(scenario.template)) ?? "render error"
    }
}

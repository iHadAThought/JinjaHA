import Foundation
import JinjaHA

@main
struct MinimalRender {
    static func main() async throws {
        let snapshot = HAStateSnapshot(
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
                    attributes: ["brightness": .int(180)]
                ),
            ],
            areas: [HAArea(areaID: "kitchen", name: "Kitchen")],
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let template = """
        Outdoor: {{ states('sensor.outdoor_temperature', with_unit=true) }}
        {% if is_state('light.kitchen', 'on') %}
        Kitchen light is on (brightness {{ state_attr('light.kitchen', 'brightness') }}).
        {% endif %}
        tau={{ tau }} ordinal={{ 1 | ordinal }}
        """

        let local = LocalTemplateRenderer(snapshot: snapshot)
        if let urlString = ProcessInfo.processInfo.environment["HA_URL"],
           let token = ProcessInfo.processInfo.environment["HA_TOKEN"],
           let baseURL = URL(string: urlString),
           !token.isEmpty
        {
            let api = HAAPITemplateRenderer(baseURL: baseURL, token: token)
            let hybrid = FallbackTemplateRenderer(primary: local, fallback: api)
            print(try await hybrid.render(template))
        } else {
            print(try await local.render(template))
        }
    }
}

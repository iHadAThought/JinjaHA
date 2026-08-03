import Foundation
import JinjaHA

@main
struct MinimalRender {
    static func main() throws {
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

        let engine = HATemplateEngine(snapshot: snapshot)
        let template = """
        Outdoor: {{ states('sensor.outdoor_temperature', with_unit=true) }}
        {% if is_state('light.kitchen', 'on') %}
        Kitchen light is on (brightness {{ state_attr('light.kitchen', 'brightness') }}).
        {% endif %}
        """

        let output = try engine.render(template)
        print(output)
    }
}

import Foundation
import JinjaCore

enum HAFilters {
    static func register(into env: Environment) {
        // HA uses snake_case aliases for some Jinja filters.
        env["to_json"] = .function { args, kwargs, environment in
            try Filters.tojson(args, kwargs: kwargs, env: environment)
        }
        env.registerFilter("to_json") { args, kwargs, environment in
            try Filters.tojson(args, kwargs: kwargs, env: environment)
        }
        env["from_json"] = .function { args, _, _ in
            guard let first = args.first else { return .null }
            let text: String
            switch first {
            case .string(let string): text = string
            default: text = first.description
            }
            guard let data = text.data(using: .utf8) else { return .null }
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try Value(any: json)
        }
        env.registerFilter("from_json") { args, _, _ in
            guard let first = args.first else { return .null }
            let text: String
            switch first {
            case .string(let string): text = string
            default: text = first.description
            }
            guard let data = text.data(using: .utf8) else { return .null }
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try Value(any: json)
        }
        // is_defined / is_number / iif / regex / etc. register in HAHelpers (Phase 4).
    }
}

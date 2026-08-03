import Foundation

/// Renders templates via Home Assistant REST `POST /api/template`.
public struct HAAPITemplateRenderer: TemplateRendering {
    public var baseURL: URL
    public var token: String
    public var session: URLSession
    public var timeout: TimeInterval

    public init(
        baseURL: URL,
        token: String,
        session: URLSession = .shared,
        timeout: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.timeout = timeout
    }

    public func render(_ template: String) async throws -> String {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HATemplateError.invalidURL
        }
        // Normalize to .../api/template
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/api") {
            path += "/template"
        } else if !path.hasSuffix("/api/template") {
            path += path.isEmpty ? "/api/template" : "/api/template"
        }
        components.path = path
        guard let url = components.url else {
            throw HATemplateError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["template": template])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HATemplateError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HATemplateError.transport("Invalid HTTP response")
        }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw HATemplateError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw HATemplateError.api(statusCode: http.statusCode, message: scrub(body))
        }

        // HA returns a JSON string (quoted) for successful renders.
        if let string = try? JSONDecoder().decode(String.self, from: data) {
            return string
        }
        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            // Some proxies may return raw text.
            if string.first == "\"", let decoded = try? JSONDecoder().decode(String.self, from: data) {
                return decoded
            }
            return string.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        throw HATemplateError.emptyResponse
    }

    private func scrub(_ message: String) -> String {
        var result = message
        if !token.isEmpty {
            result = result.replacingOccurrences(of: token, with: "[REDACTED]")
        }
        return result
    }
}

import Foundation

/// Errors produced by JinjaHA template rendering.
public enum HATemplateError: Error, Sendable, Equatable {
    case templateTooLarge(limit: Int, actual: Int)
    case outputTooLarge(limit: Int, actual: Int)
    case renderTimedOut
    case rangeTooLarge(limit: Int)
    case jinja(String)
    case api(statusCode: Int, message: String)
    case transport(String)
    case invalidURL
    case unauthorized
    case emptyResponse
    case unsupported(String)

    public var localizedDescription: String {
        switch self {
        case .templateTooLarge(let limit, let actual):
            return "Template exceeds size limit (\(actual) > \(limit) bytes)"
        case .outputTooLarge(let limit, let actual):
            return "Rendered output exceeds size limit (\(actual) > \(limit) bytes)"
        case .renderTimedOut:
            return "Template render timed out"
        case .rangeTooLarge(let limit):
            return "range() exceeds safety limit of \(limit)"
        case .jinja(let message):
            return message
        case .api(let statusCode, let message):
            return "HA template API error (\(statusCode)): \(message)"
        case .transport(let message):
            return "Transport error: \(message)"
        case .invalidURL:
            return "Invalid Home Assistant URL"
        case .unauthorized:
            return "Unauthorized — check the long-lived access token"
        case .emptyResponse:
            return "Empty template API response"
        case .unsupported(let message):
            return "Unsupported: \(message)"
        }
    }
}

extension HATemplateError: LocalizedError {
    public var errorDescription: String? { localizedDescription }
}

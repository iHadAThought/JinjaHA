import Foundation

/// Hard safety caps applied by ``HATemplateEngine``.
public struct HATemplateLimits: Sendable, Hashable {
    public var maxTemplateBytes: Int
    public var maxOutputBytes: Int
    public var maxRangeSize: Int
    public var renderTimeout: Duration?

    public static let `default` = HATemplateLimits()

    public init(
        maxTemplateBytes: Int = 100_000,
        maxOutputBytes: Int = 500_000,
        maxRangeSize: Int = 10_000,
        renderTimeout: Duration? = .seconds(2)
    ) {
        self.maxTemplateBytes = maxTemplateBytes
        self.maxOutputBytes = maxOutputBytes
        self.maxRangeSize = maxRangeSize
        self.renderTimeout = renderTimeout
    }
}

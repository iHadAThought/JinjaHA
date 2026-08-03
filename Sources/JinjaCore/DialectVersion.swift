/// Identity for the Jinja dialect this engine targets.
public enum JinjaCoreInfo: Sendable {
    /// Semantic target aligned with the Pallets Jinja 3.1.x line.
    public static let dialectVersion = "3.1"

    /// Monotonic revision of the owned JinjaCore implementation.
    public static let implementationRevision = 3

    /// Provenance note for the original vendored sources (Apache-2.0).
    public static let vendoredFrom = "huggingface/swift-jinja 2.4.2 (vendored; now owned)"
}

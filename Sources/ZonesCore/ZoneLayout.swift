/// A named collection of zones describing how a display should be subdivided.
public struct ZoneLayout: Equatable, Codable, Sendable {
    public let name: String
    public let zones: [Zone]

    public init(name: String, zones: [Zone]) {
        self.name = name
        self.zones = zones
    }
}

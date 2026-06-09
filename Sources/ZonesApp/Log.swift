import os

/// Centralised loggers. Stream them with:
///   log stream --predicate 'subsystem == "co.uk.vindraper.zones"' --level debug
enum Log {
    static let app = Logger(subsystem: "co.uk.vindraper.zones", category: "app")
    static let drag = Logger(subsystem: "co.uk.vindraper.zones", category: "drag")
    static let snap = Logger(subsystem: "co.uk.vindraper.zones", category: "snap")
}

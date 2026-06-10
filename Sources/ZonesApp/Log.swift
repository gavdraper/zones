import os

/// Centralised loggers. Stream them with:
///   log stream --predicate 'subsystem == "co.uk.vindraper.zones"' --level debug
enum Log {
    static let app = Logger(subsystem: "co.uk.vindraper.zones", category: "app")
    static let drag = Logger(subsystem: "co.uk.vindraper.zones", category: "drag")
    static let snap = Logger(subsystem: "co.uk.vindraper.zones", category: "snap")
    static let editor = Logger(subsystem: "co.uk.vindraper.zones", category: "editor")
    static let help = Logger(subsystem: "co.uk.vindraper.zones", category: "help")
}

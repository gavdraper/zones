import CoreGraphics

/// Factory for the built-in zone layouts, mirroring the FancyZones templates.
///
/// All produced zones are normalized (`0...1`, top-left origin), so they are
/// independent of any particular display size.
public enum LayoutTemplate {

    /// The built-in layouts offered out of the box, in menu order. This is the
    /// single source of truth for the defaults the app ships with.
    public static func builtins() -> [ZoneLayout] {
        [
            columns(2),
            columns(3),
            grid(rows: 2, columns: 2),
            priorityGrid()
        ]
    }

    /// `count` equal-width, full-height columns laid out left-to-right.
    public static func columns(_ count: Int) -> ZoneLayout {
        precondition(count > 0, "A column layout needs at least one column")
        let width = 1.0 / Double(count)
        let zones = (0..<count).map { index in
            Zone(
                id: index,
                normalizedFrame: CGRect(
                    x: Double(index) * width, y: 0, width: width, height: 1
                )
            )
        }
        return ZoneLayout(name: "\(count) Columns", zones: zones)
    }

    /// `rows` × `columns` uniform grid, numbered row-major from the top-left.
    public static func grid(rows: Int, columns: Int) -> ZoneLayout {
        precondition(rows > 0 && columns > 0, "A grid needs positive dimensions")
        let cellWidth = 1.0 / Double(columns)
        let cellHeight = 1.0 / Double(rows)
        var zones: [Zone] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let id = row * columns + column
                zones.append(
                    Zone(
                        id: id,
                        normalizedFrame: CGRect(
                            x: Double(column) * cellWidth,
                            y: Double(row) * cellHeight,
                            width: cellWidth,
                            height: cellHeight
                        )
                    )
                )
            }
        }
        return ZoneLayout(name: "\(rows)×\(columns) Grid", zones: zones)
    }

    /// Priority grid: a wide central zone flanked by two narrower side columns
    /// (25% / 50% / 25%). A common "focus in the middle" working layout.
    public static func priorityGrid() -> ZoneLayout {
        let zones = [
            Zone(id: 0, normalizedFrame: CGRect(x: 0.0, y: 0, width: 0.25, height: 1)),
            Zone(id: 1, normalizedFrame: CGRect(x: 0.25, y: 0, width: 0.5, height: 1)),
            Zone(id: 2, normalizedFrame: CGRect(x: 0.75, y: 0, width: 0.25, height: 1))
        ]
        return ZoneLayout(name: "Priority Grid", zones: zones)
    }
}

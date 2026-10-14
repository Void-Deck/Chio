import SwiftTUIViews

extension ChioStyle {
    /// Distinct arc, target band and needle colors for target-band dials.
    public struct GaugeColors {
        public let arc: Color
        public let target: Color
        public let needle: Color

        public init(
            arc: Color = Color(hexRGB: 0x60606B),
            target: Color = Color(hexRGB: 0xFFB9F1),
            needle: Color = Color(hexRGB: 0xFFFFFF)
        ) {
            self.arc = arc
            self.target = target
            self.needle = needle
        }

        /// Returns a new palette; omitted colors retain their current values.
        public func replacing(
            arc: Color? = nil,
            target: Color? = nil,
            needle: Color? = nil
        ) -> Self {
            GaugeColors(arc: arc ?? self.arc, target: target ?? self.target,
                        needle: needle ?? self.needle)
        }
    }
}

extension ChioStyle.GaugeColors: Codable {}
extension ChioStyle.GaugeColors: Hashable {}
extension ChioStyle.GaugeColors: Sendable {}

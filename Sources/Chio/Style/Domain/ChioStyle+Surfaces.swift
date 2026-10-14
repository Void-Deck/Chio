import SwiftTUIViews

extension ChioStyle {
    /// A surface either follows the base palette or supplies its own color.
    /// Inheritance remains live when the base palette is replaced.
    public enum Surface {
        case base
        case color(Color)

        public func resolve(base: Color) -> Color {
            switch self {
            case .base: base
            case .color(let color): color
            }
        }
    }

    /// Backgrounds that can differ from ordinary panel content.
    public struct Surfaces {
        public let canvas: Surface
        public let input: Surface

        public init(canvas: Surface = .base, input: Surface = .base) {
            self.canvas = canvas
            self.input = input
        }

        /// Omitted roles retain their values; `.base` restores palette inheritance.
        public func replacing(canvas: Surface? = nil, input: Surface? = nil) -> Self {
            Surfaces(canvas: canvas ?? self.canvas, input: input ?? self.input)
        }
    }
}

extension ChioStyle.Surface: Codable {}
extension ChioStyle.Surface: Hashable {}
extension ChioStyle.Surface: Sendable {}

extension ChioStyle.Surfaces: Codable {}
extension ChioStyle.Surfaces: Hashable {}
extension ChioStyle.Surfaces: Sendable {}

import Chio
import SwiftTUI

/// The command's closed set of themes; Chio's style values remain open.
enum MatrixTheme: String {
    case `default`, light, btop

    var style: ChioStyle {
        switch self {
        case .default: .default
        case .light: .light
        case .btop: .btop
        }
    }
}

extension MatrixTheme: CaseIterable {}
extension MatrixTheme: ExpressibleByArgument {}
extension MatrixTheme: Sendable {}

public struct RuleScope {
    public enum Layout {
        case responsibilityFirst
        case componentFirst

        public func responsibility(in directories: [String]) -> String? {
            let index: Int
            switch self {
            case .responsibilityFirst: index = 1
            case .componentFirst: index = 2
            }
            guard directories.indices.contains(index) else { return nil }
            return directories[index]
        }
    }

    public let isApplication: Bool
    public let isPure: Bool
    public let allowedImports: [String]?
    public let enforceLayout: Bool
    public let responsibilityGroups: [String]
    public let maximumDepth: Int
    public let layout: Layout

    public init(
        isApplication: Bool,
        isPure: Bool,
        allowedImports: [String]?,
        enforceLayout: Bool,
        responsibilityGroups: [String],
        maximumDepth: Int = 3
    ) {
        self.init(isApplication: isApplication, isPure: isPure, allowedImports: allowedImports,
                  enforceLayout: enforceLayout, responsibilityGroups: responsibilityGroups,
                  maximumDepth: maximumDepth, layout: .responsibilityFirst)
    }

    public init(
        isApplication: Bool,
        isPure: Bool,
        allowedImports: [String]?,
        enforceLayout: Bool,
        responsibilityGroups: [String],
        maximumDepth: Int = 3,
        layout: Layout
    ) {
        self.isApplication = isApplication
        self.isPure = isPure
        self.allowedImports = allowedImports
        self.enforceLayout = enforceLayout
        self.responsibilityGroups = responsibilityGroups
        self.maximumDepth = maximumDepth
        self.layout = layout
    }
}

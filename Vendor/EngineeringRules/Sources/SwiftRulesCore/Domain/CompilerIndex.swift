public struct CompilerIndex {
    public struct Symbol {
        public let usr: String
        public let name: String
        public let kind: UInt32

        public init(usr: String, name: String, kind: UInt32) {
            self.usr = usr
            self.name = name
            self.kind = kind
        }
    }

    public struct Relation {
        public let roles: UInt64
        public let symbol: Symbol

        public init(roles: UInt64, symbol: Symbol) {
            self.roles = roles
            self.symbol = symbol
        }
    }

    public struct Occurrence {
        public let path: String
        public let line: Int
        public let column: Int
        public let roles: UInt64
        public let symbol: Symbol
        public let relations: [Relation]

        public init(path: String, line: Int, column: Int, roles: UInt64, symbol: Symbol, relations: [Relation]) {
            self.path = path
            self.line = line
            self.column = column
            self.roles = roles
            self.symbol = symbol
            self.relations = relations
        }

        public func hasRole(_ role: UInt64) -> Bool {
            roles & role != 0
        }

        public func relatedSymbols(role: UInt64) -> [Symbol] {
            relations.filter { $0.roles & role != 0 }.map(\.symbol)
        }
    }

    public enum Role {
        public static let definition: UInt64 = 1 << 1
        public static let implicit: UInt64 = 1 << 8
        public static let childOf: UInt64 = 1 << 9
        public static let baseOf: UInt64 = 1 << 10
        public static let overrideOf: UInt64 = 1 << 11
        public static let extendedBy: UInt64 = 1 << 14
        public static let accessorOf: UInt64 = 1 << 15
        public static let containedBy: UInt64 = 1 << 16
    }

    public enum Kind {
        public static let `enum`: UInt32 = 5
        public static let `struct`: UInt32 = 6
        public static let `class`: UInt32 = 7
        public static let `protocol`: UInt32 = 8
        public static let `extension`: UInt32 = 9
        public static let function: UInt32 = 12
        public static let instanceMethod: UInt32 = 16
        public static let classMethod: UInt32 = 17
        public static let staticMethod: UInt32 = 18
        public static let instanceProperty: UInt32 = 19
        public static let classProperty: UInt32 = 20
        public static let staticProperty: UInt32 = 21
        public static let constructor: UInt32 = 22

        public static func isWitnessMember(_ kind: UInt32) -> Bool {
            [function, instanceMethod, classMethod, staticMethod, instanceProperty, classProperty, staticProperty].contains(kind)
        }
    }

    public enum MappingError {
        case missingSource(String)
        case duplicateSource(String)
        case invalidLocation(path: String, line: Int, column: Int)
        case ambiguousDefinition(String)
        case missingOwner(String)
        case ambiguousExtensionTarget(String)
        case missingDeclaration(path: String, line: Int, column: Int)
        case ambiguousDeclaration(path: String, line: Int, column: Int)
        case invalidSyntax(String)
    }

    public let occurrences: [Occurrence]
    /// Every input of the successfully typechecked module, including files with no symbols.
    public let sourcePaths: [String]

    public init(occurrences: [Occurrence], sourcePaths: [String]) {
        self.occurrences = occurrences
        self.sourcePaths = sourcePaths
    }
}

extension CompilerIndex.MappingError: Error {}

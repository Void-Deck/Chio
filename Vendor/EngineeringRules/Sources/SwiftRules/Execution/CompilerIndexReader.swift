import Foundation
import IndexStoreBridge
import SwiftRulesCore

struct CompilerIndexReader {
    private final class Collector {
        let rootComponents: [String]
        var occurrences: [CompilerIndex.Occurrence] = []
        var sourcePaths: Set<String> = []
        var failure: String?

        init(root: URL) {
            rootComponents = root.standardizedFileURL.pathComponents
        }

        func string(_ value: ISBString) -> String? {
            guard value.length > 0 else { return "" }
            guard let pointer = value.data else {
                failure = "Missing compiler index string"
                return nil
            }
            let bytes = UnsafeRawBufferPointer(start: pointer, count: value.length)
            guard let result = String(bytes: bytes, encoding: .utf8) else {
                failure = "Invalid UTF-8 in compiler index"
                return nil
            }
            return result
        }

        func relativePath(_ value: ISBString) -> String? {
            guard let path = string(value) else { return nil }
            guard !path.isEmpty else { return nil }
            guard path.hasPrefix("/") else {
                failure = "Compiler index source path must be absolute"
                return nil
            }
            let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
            guard components.count > rootComponents.count,
                  components.starts(with: rootComponents) else { return nil }
            return components.dropFirst(rootComponents.count).joined(separator: "/")
        }

        func symbol(_ value: ISBSymbol) -> CompilerIndex.Symbol? {
            guard let usr = string(value.usr), let name = string(value.name) else { return nil }
            return CompilerIndex.Symbol(usr: usr, name: name, kind: value.kind)
        }

        func receiveSource(_ mainFile: ISBString) -> Bool {
            if let path = relativePath(mainFile) { sourcePaths.insert(path) }
            return failure == nil
        }

        func receiveOccurrence(_ value: ISBOccurrence) -> Bool {
            guard let path = relativePath(value.path) else { return failure == nil }
            guard let selectedSymbol = symbol(value.symbol) else { return false }
            var relations: [CompilerIndex.Relation] = []
            if value.relation_count > 0 {
                guard let values = value.relations else {
                    failure = "Missing compiler index relations"
                    return false
                }
                for relation in UnsafeBufferPointer(start: values, count: value.relation_count) {
                    guard let relatedSymbol = symbol(relation.symbol) else { return false }
                    relations.append(CompilerIndex.Relation(roles: relation.roles, symbol: relatedSymbol))
                }
            }
            occurrences.append(CompilerIndex.Occurrence(
                path: path, line: Int(value.line), column: Int(value.column),
                roles: value.roles, symbol: selectedSymbol, relations: relations
            ))
            return true
        }
    }

    static func read(store: URL, library: URL, root: URL) throws -> CompilerIndex {
        let collector = Collector(root: root)
        let context = Unmanaged.passUnretained(collector).toOpaque()
        var error: UnsafeMutablePointer<CChar>?
        let status = isb_read(
            library.path, store.path, context,
            { context, mainFile in
                guard let context else { return false }
                return Unmanaged<Collector>.fromOpaque(context).takeUnretainedValue().receiveSource(mainFile)
            },
            { context, occurrence in
                guard let context, let occurrence else { return false }
                return Unmanaged<Collector>.fromOpaque(context).takeUnretainedValue().receiveOccurrence(occurrence.pointee)
            },
            &error
        )
        defer { isb_dispose_error(error) }
        guard status == 0, collector.failure == nil else {
            let description = collector.failure ?? error.map { String(cString: $0) } ?? "Cannot read compiler index"
            throw ToolFailure.invalid(description)
        }
        guard !collector.sourcePaths.isEmpty else {
            throw ToolFailure.invalid("Compiler index contains no source units under the repository root")
        }
        return CompilerIndex(occurrences: collector.occurrences, sourcePaths: collector.sourcePaths.sorted())
    }
}

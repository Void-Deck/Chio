import Chio
import Foundation
import SwiftTUI

@main
struct RouteReadabilityCommand {
    @Option(help: "Retained map fixtures directory, relative to the current directory.")
    var fixtureRoot = "Examples/Maps/Fixtures"
    @Option(name: .customLong("route-case"), help: "Geometry fixture: street, hairpin or crossing.")
    var scene: RouteReadabilityScene = .street
    @Option(help: "Style: default, light or btop.") var theme: Appearance = .default
    @Option(help: "Detail: minimal or source.") var detail = "minimal"
    @Flag(help: "Hide polygon fills.") var outlines = false
    @Flag(help: "Show geographic labels.") var labels = false
    @Flag(help: "Apply a local style with muted roads and coastlines.") var mutedRoads = false
    @Option(help: "Initially highlight none, start or finish without moving the camera.") var endpoint: Endpoint = .start
    @Flag(help: "Omit endpoint markers to inspect the unbroken route.") var noMarkers = false
    @Flag(help: "Export actual hosted native raster cells as JSON.") var snapshot = false
    @Option var width = 100
    @Option var height = 34
    @OptionGroup var swiftTUIOptions: SwiftTUIOptions

    enum Appearance: String {
        case `default`, light, btop
        var style: ChioStyle {
            switch self {
            case .default: .default
            case .light: .light
            case .btop: .btop
            }
        }
    }

    enum Endpoint: String {
        case none, start, finish
        var selection: String? {
            switch self {
            case .none: nil
            case .start: "start"
            case .finish: "finish"
            }
        }
    }

    private func read(_ url: URL, maximumBytes: Int) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= maximumBytes else { throw ValidationError("Fixture exceeds its byte limit.") }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw ValidationError("Fixture exceeds its byte limit.") }
        return data
    }
}

extension RouteReadabilityCommand: AsyncParsableCommand {
    mutating func validate() throws {
        let hasValidWidth = (20...240).contains(width)
        let hasValidHeight = (12...100).contains(height)
        guard hasValidWidth, hasValidHeight else { throw ValidationError("Use 20...240 columns and 12...100 rows.") }
        guard ["minimal", "source"].contains(detail) else { throw ValidationError("Use minimal or source detail.") }
    }

    @MainActor
    mutating func run() async throws {
        let root = URL(fileURLWithPath: fixtureRoot)
        guard let traceURL = Bundle.module.url(forResource: "road-trace", withExtension: "json", subdirectory: "Fixtures"),
              let metadataURL = Bundle.module.url(forResource: "source-metadata", withExtension: "json", subdirectory: "Fixtures")
        else { throw CocoaError(.fileNoSuchFile) }
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(MapSourceMetadata.self, from: read(metadataURL, maximumBytes: 8_192))
        let dataset = try MapDataset.decodeGeoJSON(read(root.appendingPathComponent("singapore.geojson"), maximumBytes: 1_048_576))
        let source = try MapSource(dataset: dataset, metadata: metadata, coverage: .boundedOfflineExtract(MapCoverage.Bounds(
            southwest: MapCoordinate(latitude: 1.278, longitude: 103.842),
            northeast: MapCoordinate(latitude: 1.3, longitude: 103.87))))
        let street = try decoder.decode(MapPolyline.self, from: read(traceURL, maximumBytes: 32_768))
        let path = try scene.path(street: street)
        let markers = try noMarkers ? [] : [
            MapMarker(id: "start", coordinate: path.coordinates[0], title: "Start"),
            MapMarker(id: "finish", coordinate: path.coordinates[path.coordinates.count - 1], title: "Finish"),
        ]
        let overlays = try MapOverlays(markers: markers, routes: [MapRoute(id: "trace", path: path)])
        let content = RouteReadabilityView(source: source, overlays: overlays, scene: scene, style: theme.style,
                                          detail: detail == "minimal" ? .minimal : .source,
                                          fills: !outlines, labels: labels, mutedRoads: mutedRoads,
                                          selection: noMarkers ? nil : endpoint.selection)
        let application = RouteReadabilityApplication(content: content)
        if snapshot {
            try await RouteReadabilityCapture.export(application, width: width, height: height, style: theme.style)
        } else {
            try await WebHostCLIRunner.run(application, configuration: swiftTUIOptions.runtimeConfiguration())
        }
    }
}

extension RouteReadabilityCommand.Appearance: ExpressibleByArgument {}
extension RouteReadabilityCommand.Endpoint: ExpressibleByArgument {}

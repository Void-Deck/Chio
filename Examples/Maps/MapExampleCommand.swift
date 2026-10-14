import Chio
import Foundation
import SwiftTUI

@main
struct MapExampleCommand {
    @Option(name: .customLong("map"), help: "Local map: world or street.")
    var scene: MapFixtures.Scene = .world
    @Option(help: "Street source: overpass or openfreemap; retained while viewing world.")
    var source: MapFixtures.StreetSource = .overpass
    @Flag(help: "Load OpenFreeMap tiles online for world, region and street views.")
    var online = false
    @Option(help: "Optional JSON OpenMapTilesSource file for --online; otherwise discover OpenFreeMap.")
    var tileSource = ""
    @Option(help: "Opt-in dedicated disk cache directory for --online. A directory belongs to one exact tile source.")
    var tileCache = ""
    @Option(help: "Open an explicitly prepared offline .chiomap tile-pack file; interactive only.")
    var tilePack = ""
    @Option(help: "Prepare an immutable zoom-one world pack from bundled tiles, then exit.")
    var writeTilePack = ""
    @Option(help: "Opt-in explicit Photon-compatible /api URL for place search; independent of --online tiles.")
    var geocoderEndpoint = ""
    @Option(help: "Opt-in explicit Photon-compatible /reverse URL for centre lookup; independent of forward search and tiles.")
    var reverseGeocoderEndpoint = ""
    @Option(help: "Opt-in explicit complete OSRM /route/v1/profile endpoint; independent of tiles and geocoding.")
    var routerEndpoint = ""
    @Flag(help: "Start with the fixed road-trace demonstration; snapshots remain offline.") var routeDemo = false
    @Option(help: "Theme: default, light or btop.") var theme: Appearance = .default
    @Flag(help: "Print a deterministic native raster as text.") var snapshot = false
    @Flag(help: "Export native raster cells as JSON for visual inspection.") var snapshotJSON = false
    @Flag(help: "Measure the first completed hosted frame, including compact fallbacks, at three terminal sizes.") var benchmark = false
    @Option(help: "Detail: silhouette, minimal, abstract or source.") var detail: MapDetail = .minimal
    @Flag(help: "Alias for --detail source; takes precedence over --detail.") var sourceDetail = false
    @Option(help: "Snapshot width, 20...240 columns.") var width = 100
    @Option(help: "Snapshot height, 12...100 rows.") var height = 30
    @Option(help: "Override cell height/width, 0.5...4. Defaults to reported metrics interactively, estimated 2 for snapshots.")
    var cellAspect: Double?
    @OptionGroup(title: "SwiftTUI options") var swiftTUIOptions: SwiftTUIOptions

    enum Appearance: String {
        case `default`, light, btop
        var theme: ChioTheme {
            switch self {
            case .default: .default
            case .light: .light
            case .btop: .btop
            }
        }
        var next: Self {
            switch self {
            case .default: .light
            case .light: .btop
            case .btop: .default
            }
        }
    }
}

extension MapExampleCommand.Appearance: ExpressibleByArgument {}
extension MapExampleCommand.Appearance: CaseIterable {}
extension MapExampleCommand.Appearance: Hashable {}
extension MapExampleCommand.Appearance: Codable {}
extension MapExampleCommand.Appearance: Sendable {}

extension MapDetail: ExpressibleByArgument {}

extension MapExampleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "chio-maps",
                                                     abstract: "World and street examples using Chio MapView; offline unless --online is supplied.")
    mutating func validate() throws {
        let hasSupportedWidth = (20...240).contains(width)
        let hasSupportedHeight = (12...100).contains(height)
        guard hasSupportedWidth, hasSupportedHeight else {
            throw ValidationError("Use width 20...240 and height 12...100.")
        }
        if let cellAspect {
            let isFiniteAspect = cellAspect.isFinite
            let hasSupportedAspect = (0.5...4).contains(cellAspect)
            guard isFiniteAspect, hasSupportedAspect else {
                throw ValidationError("Cell aspect must be finite in 0.5...4.")
            }
        }
        guard [snapshot, snapshotJSON, benchmark].filter({ $0 }).count <= 1 else {
            throw ValidationError("Choose one output mode: snapshot, snapshot-json or benchmark.")
        }
        let hasOfflineOutput = snapshot || snapshotJSON || benchmark
        let usesLivePlaces = !geocoderEndpoint.isEmpty || !reverseGeocoderEndpoint.isEmpty
        guard !usesLivePlaces || !hasOfflineOutput else {
            throw ValidationError("Live place search is interactive. Snapshot and benchmark modes use bundled data.")
        }
        guard routerEndpoint.isEmpty || !hasOfflineOutput else {
            throw ValidationError("Live routing is interactive. Snapshot and benchmark modes use bundled data.")
        }
        guard !routeDemo || !benchmark else {
            throw ValidationError("--route-demo is available for interactive and snapshot modes.")
        }
        if !routerEndpoint.isEmpty { _ = try configuredRouter() }
        if !geocoderEndpoint.isEmpty { _ = try configuredGeocoder() }
        if !reverseGeocoderEndpoint.isEmpty { _ = try configuredReverseGeocoder() }
        guard !online || !hasOfflineOutput else {
            throw ValidationError("Online mode is interactive. Snapshot and benchmark modes use bundled data.")
        }
        let isDefaultBundledSource: Bool
        switch source {
        case .overpass: isDefaultBundledSource = true
        case .openfreemap: isDefaultBundledSource = false
        }
        guard !online || isDefaultBundledSource else {
            throw ValidationError("--source selects a bundled fixture. Use --online on its own for live OpenFreeMap tiles.")
        }
        let usesPack = !tilePack.isEmpty || !writeTilePack.isEmpty
        let usesNetworkConfiguration = online || !tileSource.isEmpty || !tileCache.isEmpty
        guard !usesPack || !usesNetworkConfiguration else {
            throw ValidationError("Tile packs cannot be combined with --online, --tile-source or --tile-cache.")
        }
        guard tilePack.isEmpty || writeTilePack.isEmpty else {
            throw ValidationError("Choose --tile-pack or --write-tile-pack.")
        }
        guard !usesPack || isDefaultBundledSource else {
            throw ValidationError("--source selects a bundled fixture. Use a tile-pack option on its own.")
        }
        guard !usesPack || !hasOfflineOutput else {
            throw ValidationError("Tile-pack viewing is interactive; preparation exits after writing. Snapshot and benchmark modes use bundled data.")
        }
        guard online || tileSource.isEmpty else {
            throw ValidationError("--tile-source requires --online.")
        }
        guard online || tileCache.isEmpty else {
            throw ValidationError("--tile-cache requires --online.")
        }
    }

    private func configuredRouter() throws -> OSRMRouter {
        guard let endpoint = URL(string: routerEndpoint) else {
            throw ValidationError("--router-endpoint requires an explicit complete OSRM /route/v1/profile URL.")
        }
        return try OSRMRouter(endpoint: endpoint, userAgent: "ChioMaps/0.1 (https://github.com/echoz/Chio)", attributions: [
            MapAttribution(text: "OSRM", link: URL(string: "https://project-osrm.org/")!),
            MapAttribution(text: "© OpenStreetMap contributors", link: URL(string: "https://www.openstreetmap.org/copyright")!)
        ])
    }

    private func configuredGeocoder() throws -> PhotonGeocoder {
        guard let endpoint = URL(string: geocoderEndpoint) else {
            throw ValidationError("--geocoder-endpoint requires an explicit Photon /api URL.")
        }
        return try PhotonGeocoder(endpoint: endpoint, userAgent: "ChioMaps/0.1 (https://github.com/echoz/Chio)")
    }

    private func configuredReverseGeocoder() throws -> PhotonReverseGeocoder {
        guard let endpoint = URL(string: reverseGeocoderEndpoint) else {
            throw ValidationError("--reverse-geocoder-endpoint requires an explicit Photon /reverse URL.")
        }
        return try PhotonReverseGeocoder(endpoint: endpoint, userAgent: "ChioMaps/0.1 (https://github.com/echoz/Chio)")
    }

    @MainActor
    mutating func run() async throws {
        if !writeTilePack.isEmpty {
            try await MapExamplePack.writeWorld(at: URL(fileURLWithPath: writeTilePack))
            print("Prepared offline world tile pack: \(writeTilePack)")
            return
        }
        let fixtures = try MapFixtures.load()
        let detail: MapDetail = sourceDetail ? .source : self.detail
        let acquisition: MapExampleAcquisition
        if online {
            if tileSource.isEmpty {
                acquisition = .openFreeMap
            } else {
                acquisition = try .configured(file: tileSource)
            }
        } else {
            acquisition = .offline
        }
        if benchmark {
            try await MapCapture.benchmark(fixtures: fixtures, appearance: theme, cellAspect: cellAspect,
                                           detail: detail, streetSource: source)
        } else if snapshot || snapshotJSON {
            let capture = try await MapCapture.snapshot(fixtures: fixtures, scene: scene, appearance: theme,
                                                        width: width, height: height, cellAspect: cellAspect,
                                                        detail: detail, streetSource: source, routeDemo: routeDemo)
            if snapshotJSON {
                try MapCapture.export(capture.raster, background: theme.theme.colors.surface,
                                      foreground: theme.theme.colors.foreground)
            } else { print(capture.raster.lines.joined(separator: "\n")) }
        } else {
            let cacheOwner: MapTileCache?
            let packOwner: MapTilePack?
            let liveAcquisition: MapExampleAcquisition
            if !tilePack.isEmpty {
                let pack = try MapTilePack.open(at: URL(fileURLWithPath: tilePack))
                packOwner = pack
                cacheOwner = nil
                liveAcquisition = .pack(MapTileLoader(pack: pack))
            } else if tileCache.isEmpty {
                packOwner = nil
                cacheOwner = nil
                liveAcquisition = acquisition
            } else {
                packOwner = nil
                let cache: MapTileCache
                do { cache = try await acquisition.openCache(directory: URL(fileURLWithPath: tileCache)) }
                catch MapTileCache.CacheError.alreadyInUse {
                    throw ValidationError("Tile cache is already in use. Close its other map session or choose another directory.")
                } catch MapTileCache.CacheError.sourceMismatch {
                    throw ValidationError("Tile cache belongs to a different source. Choose another --tile-cache directory.")
                }
                cacheOwner = cache
                liveAcquisition = .cached(MapTileLoader(cache: cache))
            }
            let geocoder: any MapGeocodingProvider
            if geocoderEndpoint.isEmpty { geocoder = MapFixtureGeocoder() }
            else { geocoder = try configuredGeocoder() }
            let reverseGeocoder: any MapReverseGeocodingProvider
            if reverseGeocoderEndpoint.isEmpty { reverseGeocoder = MapFixtureGeocoder() }
            else { reverseGeocoder = try configuredReverseGeocoder() }
            let router: any MapRoutingProvider
            if routerEndpoint.isEmpty { router = MapFixtureRouter() }
            else { router = try configuredRouter() }
            do {
                try await WebHostCLIRunner.run(MapExampleApplication(fixtures: fixtures, scene: scene, appearance: theme,
                                                               cellAspect: cellAspect,
                                                               detail: detail, streetSource: source, acquisition: liveAcquisition, geocoder: geocoder,
                                                               searchLabel: geocoderEndpoint.isEmpty ? "Synthetic fixtures" : "Explicit Photon endpoint",
                                                               reverseGeocoder: reverseGeocoder,
                                                               lookupLabel: reverseGeocoderEndpoint.isEmpty ? "Synthetic fixtures" : "Explicit Photon endpoint",
                                                               router: router, routerLabel: routerEndpoint.isEmpty ? "Synthetic road trace" : "Explicit OSRM endpoint",
                                                               routeDemo: routeDemo),
                                          configuration: swiftTUIOptions.runtimeConfiguration())
            } catch {
                await cacheOwner?.close()
                await packOwner?.close()
                throw error
            }
            await cacheOwner?.close()
            await packOwner?.close()
        }
    }
}

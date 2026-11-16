// Spec-derived from the force-unwrap removal contract (C1–C3); separate author.
@testable import Chio
import Foundation
import Testing

struct MapTileStorageForceUnwrapSpecTests {
    @Test("C1: cache preserves every byte, including accepted empty payloads",
          arguments: [Data(), Data([0, 255, 128, 0, 13, 10]), Data((0...255).map { UInt8($0) })])
    func cacheByteRoundTrip(_ payload: Data) async throws {
        let directory = location()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try source()
        let tile = try MapTileCoordinate(zoom: 1, x: 0, y: 0)
        let cache = try MapTileCache.open(directory: directory, source: source, at: 100)
        do {
            try await cache.store(payload, for: tile, storedAt: 100, expiresAt: 200)
            let entry = try #require(try await cache.read(tile, at: 150))
            #expect(entry.data == payload)
            await cache.close()
        } catch {
            await cache.close()
            throw error
        }
        // Reopening exercises file reads rather than only the original writer.
        let reopened = try MapTileCache.open(directory: directory, source: source, at: 150)
        do {
            let entry = try #require(try await reopened.read(tile, at: 150))
            #expect(entry.data == payload)
            await reopened.close()
        } catch {
            await reopened.close()
            throw error
        }
    }

    @Test("C1: packs preserve every byte through create and reopen, including empty payloads",
          arguments: [Data(), Data([0, 255, 128, 0, 13, 10]), Data((0...255).map { UInt8($0) })])
    func packByteRoundTrip(_ payload: Data) async throws {
        let file = location()
        defer { try? FileManager.default.removeItem(at: file) }
        let plan = try worldPlan()
        let pack = try await MapTilePack.create(at: file, plan: plan, metadata: metadata()) { _ in payload }
        do {
            for tile in plan.tiles {
                let loaded = try #require(try await pack.read(tile))
                #expect(loaded == payload)
            }
            await pack.close()
        } catch {
            await pack.close()
            throw error
        }
        let reopened = try MapTilePack.open(at: file)
        do {
            for tile in plan.tiles {
                let loaded = try #require(try await reopened.read(tile))
                #expect(loaded == payload)
            }
            await reopened.close()
        } catch {
            await reopened.close()
            throw error
        }
    }

    @Test("C1: forced disk entry evictions retain exactly the newest payloads")
    func diskEntryEvictions() async throws {
        let directory = location()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try MapTileCache.open(directory: directory, source: source(), maximumEntries: 2, at: 100)
        let tiles = try (0..<4).map { try MapTileCoordinate(zoom: 2, x: $0, y: 0) }
        let payloads = [Data([0]), Data([1, 1]), Data([2, 2, 2]), Data([3, 3, 3, 3])]
        do {
            for index in tiles.indices {
                try await cache.store(payloads[index], for: tiles[index], storedAt: Double(100 + index), expiresAt: 200)
            }
            #expect(try await cache.read(tiles[0], at: 150) == nil)
            #expect(try await cache.read(tiles[1], at: 150) == nil)
            #expect(try await cache.read(tiles[2], at: 150)?.data == payloads[2])
            #expect(try await cache.read(tiles[3], at: 150)?.data == payloads[3])
            await cache.close()
        } catch {
            await cache.close()
            throw error
        }
    }

    @Test("C1: forced memory byte evictions report the exact retained payload total")
    func memoryByteAccounting() async throws {
        let file = location()
        defer { try? FileManager.default.removeItem(at: file) }
        // A length-delimited unknown MVT field: valid empty tile data with a
        // controlled size. No expected accounting depends on decoder internals.
        let payload = paddedEmptyTile(byteCount: 12 * 1_024 * 1_024)
        let pack = try await MapTilePack.create(at: file, plan: worldPlan(), metadata: metadata()) { _ in payload }
        do {
            let loader = MapTileLoader(pack: pack)
            let request = try MapTileRequest(
                camera: MapCamera(center: MapCoordinate(latitude: 0, longitude: 0), longitudeSpan: 360),
                viewport: MapViewport(columns: 100, rows: 30))
            for _ in 0..<2 {
                _ = try await loader.load(request)
                let statistics = await loader.statistics()
                // Four supplied tiles exceed the documented 32 MiB limit;
                // exactly two of these equal-sized responses fit.
                #expect(statistics.cacheEntries == 2)
                #expect(statistics.cacheBytes == 2 * payload.count)
            }
            await pack.close()
        } catch {
            await pack.close()
            throw error
        }
    }

    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("chio-force-spec-\(UUID().uuidString)")
    }

    private func metadata() throws -> MapSourceMetadata {
        let url = try #require(URL(string: "https://example.test/tiles"))
        return try MapSourceMetadata(attribution: "Spec fixture", license: "Fixture", licenseURL: url,
                                     sourceURL: url, sourceRevision: "spec-1")
    }

    private func source() throws -> OpenMapTilesSource {
        try OpenMapTilesSource(template: "https://example.test/{z}/{x}/{y}.pbf", zoomRange: 0...4, metadata: metadata())
    }

    private func worldPlan() throws -> MapTilePackPlan {
        let bounds = try MapCoverage.Bounds(southwest: MapCoordinate(latitude: -85, longitude: -180),
                                            northeast: MapCoordinate(latitude: 85, longitude: 180))
        return try MapTilePackPlan(bounds: bounds, zoomRange: 1...1)
    }

    private func paddedEmptyTile(byteCount: Int) -> Data {
        var length = byteCount
        var data = Data([0x0a])
        while length >= 128 {
            data.append(UInt8(length & 127) | 128)
            length >>= 7
        }
        data.append(UInt8(length))
        data.append(Data(repeating: 0, count: byteCount))
        return data
    }
}

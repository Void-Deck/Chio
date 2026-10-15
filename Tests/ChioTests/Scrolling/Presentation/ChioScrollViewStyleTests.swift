import Chio
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct ChioScrollViewStyleTests {
    @Test("Native scroll tracks retain their glyphs and geometry with themed muted paint",
          arguments: [ChioStyle.default, .light, scrollTestTheme],
          [SwiftTUIViews.Axis.Set.vertical, .horizontal, [.vertical, .horizontal]])
    func indicators(theme: ChioStyle, axes: SwiftTUIViews.Axis.Set) throws {
        let rendered = DefaultRenderer().render(
            ScrollView(axes) { scrollTestContent }
                .frame(width: 12, height: 7)
                .background(theme.colors.selectedSurface)
                .style(theme),
            proposal: ProposedViewSize(width: 12, height: 7)
        )
        let native = DefaultRenderer().render(
            ScrollView(axes) { scrollTestContent }
                .scrollViewStyle(AutomaticScrollViewStyle())
                .frame(width: 12, height: 7)
                .background(theme.colors.selectedSurface)
                .style(theme),
            proposal: ProposedViewSize(width: 12, height: 7)
        )
        #expect(rendered.rasterSurface.lines == native.rasterSurface.lines)
        let route = try #require(rendered.semanticSnapshot.scrollRoutes.first)
        let nativeRoute = try #require(native.semanticSnapshot.scrollRoutes.first)
        #expect(route.viewportRect == nativeRoute.viewportRect)
        #expect(route.contentBounds == nativeRoute.contentBounds)
        #expect(route.viewportRect.size.width == (axes.contains(.vertical) ? 11 : 12))
        #expect(route.viewportRect.size.height == (axes.contains(.horizontal) ? 6 : 7))
        let cells = rendered.rasterSurface.cells.flatMap { $0 }
        #expect(cells.contains { $0.character == "▐" } == axes.contains(.vertical))
        #expect(cells.contains { $0.character == "▂" } == axes.contains(.horizontal))
        let indicators = cells.filter { $0.character == "▐" || $0.character == "▂" }
        #expect(!indicators.isEmpty)
        #expect(indicators.allSatisfy { $0.style?.foregroundColor == theme.colors.mutedText })
        #expect(cells.allSatisfy { $0.style?.backgroundColor == theme.colors.selectedSurface })
        #expect(rendered.rasterSurface.lines[0].hasPrefix("00 ABC"))
    }

    @Test("Hidden indicators return their reserved cells to native content")
    func hiddenIndicators() throws {
        let rendered = DefaultRenderer().render(
            ScrollView([.vertical, .horizontal]) { scrollTestContent }
                .scrollIndicators(.hidden)
                .style(.default),
            proposal: ProposedViewSize(width: 12, height: 7)
        )
        let route = try #require(rendered.semanticSnapshot.scrollRoutes.first)
        #expect(route.viewportRect.size.width == 12)
        #expect(route.viewportRect.size.height == 7)
        #expect(!rendered.rasterSurface.cells.flatMap { $0 }.contains {
            $0.character == "▐" || $0.character == "▂"
        })
        #expect(rendered.semanticSnapshot.focusRegions.count == 1)
        #expect(rendered.semanticSnapshot.accessibilityNodes.contains { $0.role == .scrollView })
    }

    @Test("Disabled native scrolling reports unavailable semantics and has no focus targets")
    func disabled() throws {
        let rendered = DefaultRenderer().render(
            ScrollView([.vertical, .horizontal]) { scrollTestContent }
                .disabled(true)
                .style(scrollTestTheme),
            proposal: ProposedViewSize(width: 12, height: 7)
        )
        let node = try #require(rendered.semanticSnapshot.accessibilityNodes.first {
            $0.role == .scrollViewWithIndicators
        })
        #expect(!node.isEnabled)
        #expect(rendered.semanticSnapshot.focusRegions.isEmpty)
        #expect(rendered.rasterSurface.lines[0].hasPrefix("00 ABC"))
        #expect(rendered.rasterSurface.cells.flatMap { $0 }.contains { $0.character == "▐" })
        #expect(rendered.rasterSurface.cells.flatMap { $0 }.contains { $0.character == "▂" })
    }

    @Test("Native keys, wheel and track drag retain the binding through theme and resize",
          arguments: [false, true])
    func nativeInteraction(suppressed: Bool) async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(
            surfaceSize: CellSize(width: 24, height: 10), appearance: .fallback,
            onFrame: { recorder.receive($0) }
        )
        let session = try HostedSceneSession(
            for: ScrollStyleTestApp(suppressed: suppressed), sceneID: "scroll-style", surface: surface
        )
        let run = Task { try await session.start() }
        do {
            let initial = try await recorder.wait(description: "native viewport focus preserves its first row") {
                $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 1, y: 0)
            }
            expectIndicatorPaint(initial, vertical: suppressed ? scrollTestTheme.colors.mutedText : scrollTestTheme.colors.accent,
                                 horizontal: suppressed ? scrollTestTheme.colors.mutedText : scrollTestTheme.colors.accent)
            // Native horizontal reveal still includes the reserved track column.
            // An oversized vertical target keeps its first row visible instead.
            // Establish the origin with native keys before exercising both axes.
            session.send([.key(.home), .key(.arrowLeft)])
            _ = try await recorder.wait(after: initial.sequence, description: "native keys establish the origin") {
                $0.scrollTestOffset(x: 0, y: 0)
            }
            session.send([
                .key(.arrowRight), .key(.arrowDown), .key(.arrowRight),
                .key(.arrowDown), .key(.arrowDown),
            ])
            let stepped = try await recorder.wait(after: initial.sequence, description: "batched native arrows retain every step") {
                $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 2, y: 3)
            }
            #expect(stepped.focusedIdentity == initial.focusedIdentity)

            session.send(.key(.end))
            let end = try await recorder.wait(after: stepped.sequence, description: "native both-axis End reaches the final row") {
                guard let route = $0.semantics.scrollRoutes.first else { return false }
                return $0.scrollTestOffset(x: 2, y: route.contentBounds.size.height - route.viewportRect.size.height)
            }
            session.send(.key(.home))
            let home = try await recorder.wait(after: end.sequence, description: "native Home preserves the horizontal offset") {
                $0.scrollTestOffset(x: 2, y: 0)
            }
            let viewport = try #require(home.semantics.scrollRoutes.first).viewportRect
            session.send(.mouse(MouseEvent(kind: .scrolled(deltaX: 3, deltaY: 4),
                                           location: .cellFallback(viewport.origin))))
            let wheeled = try await recorder.wait(after: home.sequence, description: "native wheel changes both declared axes") {
                $0.scrollTestOffset(x: 5, y: 4)
            }
            #expect(wheeled.focusedIdentity == initial.focusedIdentity)

            session.send(.key(.character("t"), modifiers: .ctrl))
            let themed = try await recorder.wait(after: wheeled.sequence, description: "light theme keeps native focus and position") {
                $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 5, y: 4)
                    && $0.raster.lines[0].contains("light")
            }
            #expect(themed.focusedIdentity == initial.focusedIdentity)
            expectIndicatorPaint(themed, vertical: suppressed ? ChioStyle.light.colors.mutedText : ChioStyle.light.colors.accent,
                                 horizontal: suppressed ? ChioStyle.light.colors.mutedText : ChioStyle.light.colors.accent)
            surface.updateSurfaceSize(CellSize(width: 18, height: 8))
            session.requestSurfaceRefresh()
            let resized = try await recorder.wait(after: themed.sequence, description: "compact viewport keeps the bound offset") {
                $0.raster.size.width == 18 && $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 5, y: 4)
            }
            #expect(resized.focusedIdentity == initial.focusedIdentity)

            let route = try #require(resized.semantics.scrollRoutes.first)
            // The native vertical track sits immediately outside the reserved content viewport.
            let track = try #require(resized.semantics.focusRegions.first {
                $0.identity != resized.focusedIdentity && $0.rect.size.width == 1
                    && $0.rect.origin.x == route.viewportRect.maxX
                    && $0.rect.origin.y == route.viewportRect.origin.y
            })
            let top = track.rect.origin
            let middle = CellPoint(x: top.x, y: top.y + 3)
            let bottom = CellPoint(x: top.x, y: track.rect.maxY - 1)
            #expect(track.rect.size.height == 7)
            #expect(route.viewportRect.size.height == 6)
            #expect(route.contentBounds.size.height == 20)
            // Track focus reveals its reserved column but keeps the first row.
            // Release halfway along the seven-cell track: 3/6 of its 14-row range.
            // A changed offset verifies release routing without waiting on a no-op.
            session.send(.mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(top))))
            let trackPressed = try await recorder.wait(after: resized.sequence, description: "native track focus keeps the first row visible") {
                $0.focusedIdentity == track.identity && $0.scrollTestOffset(x: 6, y: 0)
            }
            session.send(.mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(middle))))
            let trackFocused = try await recorder.wait(after: trackPressed.sequence, description: "release halfway along the track selects row seven") {
                $0.focusedIdentity == track.identity && $0.scrollTestOffset(x: 6, y: 7)
            }
            session.send([
                .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(top))),
                .mouse(MouseEvent(kind: .dragged(.primary), location: .cellFallback(bottom))),
                .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(bottom))),
            ])
            let dragged = try await recorder.wait(after: trackFocused.sequence, description: "native indicator capture reaches the last row") {
                $0.focusedIdentity == track.identity
                    && $0.scrollTestOffset(x: 6, y: route.contentBounds.size.height - route.viewportRect.size.height)
            }
            expectIndicatorPaint(dragged, vertical: suppressed ? ChioStyle.light.colors.mutedText : ChioStyle.light.colors.accent,
                                 horizontal: ChioStyle.light.colors.mutedText)
            session.send(.key(.home))
            let trackHome = try await recorder.wait(after: dragged.sequence, description: "focused native indicator Home affects only its axis") {
                $0.focusedIdentity == track.identity && $0.scrollTestOffset(x: 6, y: 0)
            }
            session.send(.key(.tab, modifiers: .shift))
            let body = try await recorder.wait(after: trackHome.sequence, description: "Shift-Tab returns to the viewport without skipping its first row") {
                $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 7, y: 0)
            }
            #expect(body.focusedIdentity == initial.focusedIdentity)
            #expect(body.scrollTestOffset(x: 7, y: 0))
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("The automatic style also preserves the first row during initial focus reveal")
    func automaticFocusReveal() async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 24, height: 10), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: ScrollStyleTestApp(native: true), sceneID: "scroll-style", surface: surface)
        let run = Task { try await session.start() }
        do {
            _ = try await recorder.wait(description: "automatic native style preserves its first row") {
                $0.scrollTestBodyFocused && $0.scrollTestOffset(x: 1, y: 0)
            }
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    private func expectIndicatorPaint(_ frame: SemanticHostFrame, vertical: Color, horizontal: Color) {
        let cells = frame.raster.cells.flatMap { $0 }
        let verticalCells = cells.filter { $0.character == "▐" }
        let horizontalCells = cells.filter { $0.character == "▂" }
        #expect(!verticalCells.isEmpty && !horizontalCells.isEmpty)
        #expect(verticalCells.allSatisfy { $0.style?.foregroundColor == vertical })
        #expect(horizontalCells.allSatisfy { $0.style?.foregroundColor == horizontal })
    }
}

private let scrollTestTheme = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
    accent: Color(hexRGB: 0x123456), mutedText: Color(hexRGB: 0x345678),
    selectedSurface: Color(hexRGB: 0x654321)
))

@MainActor
private var scrollTestContent: some View {
    Text((0..<20).map { "\($0 < 10 ? "0" : "")\($0) ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789" }.joined(separator: "\n"))
        .frame(width: 40, height: 20, alignment: .topLeading)
}

private struct ScrollStyleTestApp {
    let suppressed: Bool
    let native: Bool
    nonisolated init() { suppressed = false; native = false }
    nonisolated init(suppressed: Bool = false, native: Bool = false) {
        self.suppressed = suppressed
        self.native = native
    }
}

extension ScrollStyleTestApp: App {
    var body: some Scene {
        WindowGroup(id: "scroll-style") { ScrollStyleTestView(suppressed: suppressed, native: native) }.exitOnKeys([])
    }
}

@MainActor
private struct ScrollStyleTestView {
    let suppressed: Bool
    let native: Bool
    @State private var position = ScrollCellOffset.zero
    @State private var light = false
    @FocusState private var reading: Bool
}

extension ScrollStyleTestView: View {
    var body: some View {
        let scrollStyle: AnyScrollViewStyle
        if native {
            scrollStyle = AnyScrollViewStyle(AutomaticScrollViewStyle())
        } else {
            let theme = light ? ChioStyle.light : scrollTestTheme
            scrollStyle = AnyScrollViewStyle(ChioScrollViewStyle(theme: theme))
        }
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(position.x),\(position.y) \(light ? "light" : "custom")")
            ScrollView([.vertical, .horizontal], position: $position) { scrollTestContent }
                .scrollViewStyle(scrollStyle)
                .focused($reading)
                .accessibilityLabel("Viewport")
                .focusEffectDisabled(suppressed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .style(light ? .light : scrollTestTheme)
        .onAppear { reading = true }
        .onKeyPress { press in
            guard press == KeyPress(.character("t"), modifiers: .ctrl) else { return .ignored }
            light.toggle()
            return .handled
        }
    }
}

private extension SemanticHostFrame {
    var scrollTestBodyFocused: Bool {
        semantics.accessibilityNodes.contains {
            $0.identity == focusedIdentity && $0.label == "Viewport"
                && $0.role == .scrollViewWithIndicators
        }
    }

    func scrollTestOffset(x: Int, y: Int) -> Bool {
        semantics.scrollRoutes.first?.contentOffset == CellPoint(x: x, y: y)
            && raster.lines[0].hasPrefix("\(x),\(y) ")
    }
}

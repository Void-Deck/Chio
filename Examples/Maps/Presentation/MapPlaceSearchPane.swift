import Chio
import Foundation
import SwiftTUI

@MainActor
struct MapPlaceSearchPane {
    let label: String
    let lookupLabel: String
    let draft: Binding<String>
    // Rendering and activation retain their accepted response snapshot. Only
    // deferred focus delivery reads the parent's current state.
    let phase: MapPlaceSearch.Phase
    let currentPhase: Binding<MapPlaceSearch.Phase>
    let isPresented: Binding<Bool>
    let selection: Binding<Int?>
    let focus: FocusState<MapExampleView.Focus?>.Binding
    let submit: @MainActor () -> Void
    let open: @MainActor (MapPlace, [MapPlaceMatches.Attribution]) -> Void
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.chioTheme) private var theme

    private struct Row: Identifiable {
        struct ID: Hashable, Sendable {
            let response: UUID
            let index: Int
        }
        let id: ID
        let place: MapPlace
    }

    private var accepted: (matches: MapPlaceMatches, response: UUID)? {
        switch phase {
        case .matches(_, let matches, let response): return (matches, response)
        case .idle, .loading, .failed: return nil
        }
    }

    private func activate(_ index: Int) {
        guard let accepted, accepted.matches.places.indices.contains(index) else { return }
        open(accepted.matches.places[index], accepted.matches.attributions)
    }

    private var lookupSubject: String {
        switch phase {
        case .loading(let request), .matches(let request, _, _):
            switch request {
            case .search: return ""
            case .reverse: return request.subject
            }
        case .failed, .idle: return ""
        }
    }
}

extension MapPlaceSearchPane: View {
    var body: some View {
        let accepted = accepted
        let rows = accepted.map { accepted in
            accepted.matches.places.enumerated().map { index, place in
                Row(id: Row.ID(response: accepted.response, index: index), place: place)
            }
        } ?? []
        let rowSelection = Binding<Row.ID?>(get: {
            guard let accepted, let index = selection.wrappedValue,
                  accepted.matches.places.indices.contains(index) else { return nil }
            return Row.ID(response: accepted.response, index: index)
        }, set: { selection.wrappedValue = $0?.index })
        VStack(alignment: .leading, spacing: 0) {
            Text("Place search").bold().foregroundStyle(theme.colors.accent)
                .frame(height: 1, alignment: .leading)
            if !lookupSubject.isEmpty {
                Text(lookupSubject).foregroundStyle(theme.colors.secondaryText)
                    .frame(height: 1, alignment: .leading).clipped()
            }
            TextField("Place name", text: draft)
                .focused(focus, equals: .field)
                .onSubmit(submit)
                .onKeyPress(.arrowDown) { _ in
                    guard !rows.isEmpty else { return .ignored }
                    focus.wrappedValue = .results
                    return .handled
                }
            Group {
                switch phase {
                case .idle:
                    Text("\(label) · Return submits").foregroundStyle(theme.colors.mutedText)
                case .loading(let request):
                    switch request {
                    case .search(let query):
                        Text("Searching: \(query.text)").foregroundStyle(theme.colors.secondaryText)
                    case .reverse:
                        Text("Looking up · \(lookupLabel)").foregroundStyle(theme.colors.secondaryText)
                    }
                case .failed(_, let message):
                    Text(message).foregroundStyle(theme.colors.warning)
                case .matches(_, let matches, _):
                    if matches.places.isEmpty {
                        Text("No matches").foregroundStyle(theme.colors.secondaryText)
                    } else {
                        let noun = matches.places.count == 1 ? "match" : "matches"
                        Text("\(matches.places.count) \(noun) · Return opens")
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                }
            }.frame(height: terminalSize.height < 24 ? 1 : 2, alignment: .topLeading).clipped()
            // Keep one native focus target throughout loading, empty and failed states.
            // Only the response-scoped row identities change with accepted results.
            GeometryReader { geometry in
                List(rows, selection: rowSelection, onActivate: { activate($0.index) }) { row in
                    Text(row.place.name)
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 1).clipped()
                        .foregroundStyle(theme.colors.foreground)
                        .background(row.id == rowSelection.wrappedValue ? theme.colors.selectedSurface : theme.colors.surface)
                }
                .focusable()
                .focused(focus, equals: .results)
                .onKeyPress(.character("/")) { _ in
                    focus.wrappedValue = .field
                    return .handled
                }
                .onKeyPress(.return) { _ in
                    if let index = selection.wrappedValue { activate(index) }
                    return .handled
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let accepted {
                if terminalSize.height >= 24, let index = selection.wrappedValue,
                   accepted.matches.places.indices.contains(index) {
                    Text(accepted.matches.places[index].detail).foregroundStyle(theme.colors.secondaryText)
                        .frame(height: 2, alignment: .topLeading).clipped()
                }
                ForEach(Array(accepted.matches.attributions.indices), id: \.self) { index in
                    Link(accepted.matches.attributions[index].text,
                         destination: LinkDestination(accepted.matches.attributions[index].link.absoluteString))
                        .foregroundStyle(theme.colors.mutedText).frame(height: 1, alignment: .leading).clipped()
                }
            }
            Text("Return submit/open · Esc map").foregroundStyle(theme.colors.accent)
                .frame(height: 1, alignment: .leading).clipped()
            Text("^L look up centre").foregroundStyle(theme.colors.mutedText)
                .frame(height: 1, alignment: .leading).clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: accepted?.response, initial: true) { _, _ in
            // A retained callback may run after acceptance or dismissal has
            // advanced the parent. Decide from current storage at delivery.
            guard isPresented.wrappedValue else { return }
            let requestedFocus: MapExampleView.Focus
            switch currentPhase.wrappedValue {
            case .matches(_, let matches, _) where !matches.places.isEmpty:
                requestedFocus = .results
            case .idle, .loading, .failed, .matches:
                requestedFocus = .field
            }
            if focus.wrappedValue != requestedFocus {
                focus.wrappedValue = requestedFocus
            }
        }
    }
}

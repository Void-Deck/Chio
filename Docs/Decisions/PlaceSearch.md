# Place search

**Status:** Accepted for implementation, 2026-10-12. The candidate is not yet
released. This is the first slice of the approved geocoding scope;
[Plan](../Plan.md#approved-map-expansion) retains reverse lookup and routing as
later work. Provider archive downloads remain paused.

## First useful outcome

Type a place name, submit with Return, choose a result, then explicitly open it
on the map. Reuse Chio's styles and SwiftTUI's text field, list, focus and layout.
`MapView` receives ordinary camera/overlay values; it acquires nothing itself.
No search request is sent merely by typing, moving the map or changing style.

`SearchableList` owns local matching, ranking and Return-to-results behavior.
Those contracts do not fit remote submission or preserving provider ranking.
The example composes native controls. It does not wrap that view, add provider
callbacks to its style, or create a public map-search widget.

## Provider choice

The first adapter is configurable **Photon** forward search. Endpoint
selection is explicit and independent of the tile source. A Photon-compatible
endpoint can change without changing the UI; another protocol implementation
can supply a different provider. This does not imply universal GeoJSON support.

| Candidate | Fit for this slice | Operating constraint |
| --- | --- | --- |
| [Photon](https://github.com/komoot/photon#demo-server) | Forward place search with GeoJSON points; public demo and self-hosting options. | Public demo permits reasonable use, can throttle or ban extensive use, and gives no availability guarantee or numeric quota. Make public access an explicit, low-volume example option. |
| [Nominatim](https://operations.osmfoundation.org/policies/nominatim/) | A possible later adapter to an application-selected instance. | OSMF's public instance caps aggregate application traffic at one request/second, requires identifying requests and attribution, and forbids autocomplete. Its policy also restricts generic integration through no-code/low-code/vibe-coding platforms. Do not make it a library default. These public-instance restrictions do not govern self-hosted instances. |
| [Geoapify](https://apidocs.geoapify.com/docs/geocoding/forward-geocoding/) | A later hosted adapter with account-based quotas. | Requires an application-owned API key and applicable account/attribution terms. Keep credential storage and plan choice outside Chio. |

Photon's qualitative public-service allowance is not a promised production quota.
One request at a time and conservative submission spacing in the example are
our choices, not a guarantee of permission at any aggregate traffic level.
Use synthetic fixtures for normal examples, tests and Pages recordings.
Opt-in live probes use public landmarks, with no personal queries or credentials.
The reviewed Photon documentation provides no demo-specific retention guarantee.

## Public surface

The first implementation follows this shape:

```swift
public protocol MapGeocodingProvider: Sendable {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches
}

let geocoder = try PhotonGeocoder(
    endpoint: photonEndpoint,
    userAgent: applicationIdentity
)
let query = try MapPlaceQuery(text: searchText, limit: 8)
let matches = try await geocoder.search(query)
```

- `MapPlaceQuery`: immutable query text and result limit. Reject blank/control
  text, more than 512 UTF-8 bytes, or limits outside `1...10`; default to 8.
  Do not silently rewrite nonblank user text. No bounds, bias, language or
  autocomplete configuration in this first slice.
- `MapPlace`: `coordinate: MapCoordinate`, `name: String`, `detail: String`.
  Require a nonblank, terminal-safe name up to 256 UTF-8 bytes; detail defaults
  to empty and is limited to 1,024 bytes. Retain geographic coordinates at the
  poles even though the Mercator camera cannot centre on them.
- `MapPlaceMatches`: ordered `[MapPlace]` and required attribution entries,
  including for an empty match set. Cap the array at 10; the adapter also checks
  the requested limit. Require 1...4 attribution entries. A nested `Attribution`
  owns nonblank, control-free display text up to 1,024 UTF-8 bytes and an absolute
  HTTP(S) link up to 2,048 bytes with a host and no embedded credentials.
  Keep provider/data credits with the response and visible
  alongside results and the selected place, independently of tile credits.
- `PhotonGeocoder`: immutable endpoint and application identity; construction
  does no I/O. Require an explicit API URL, without credentials, query or fragment.
  Bound the absolute endpoint URL to 2,048 UTF-8 bytes. Application identity must
  be nonblank printable ASCII and at most 256 bytes, suitable for User-Agent.
  Use HTTPS remotely; HTTP is only for explicit loopback development. No hidden
  default host, credential lookup, global client or shared application state.

Query, place, matches and attribution values conform to `Hashable`,
`Codable` and `Sendable`, with decoding enforcing the same construction bounds.
The provider protocol is an effect boundary, not a pure style or normalization
adapter. Keep its throws open so third-party providers can retain their error
contracts. The concrete Photon operation uses a typed failure covering
cancellation, deadline, HTTP rejection, malformed/oversized data and transport
failure, preserving underlying causes. Live failures and clients do not acquire
artificial Codable/Hashable conformances.

There is no permanent provider place ID in this first public value. A response
may contain equal places; retain order and multiplicity. The application assigns
list IDs scoped to its accepted response and an independently owned marker ID.
Provider references are not application selection identities.
`MapMarker` is deliberately not reused as the search result: it owns authored
annotation identity, whereas a provider match is an observation. Reuse its
`MapCoordinate`, then explicitly construct a marker when a result is opened.

Do not reuse `MapSourceMetadata` by inventing a dataset revision for a geocoder.
Do not reuse `MapCoverage.Bounds` for provider extents: it promises a strictly
nonwrapping coverage box, not every possible place extent. Omit extents and
automatic fit-to-place zoom in this slice; keep the application's current zoom.

## Adapter and execution boundaries

Decode Photon responses privately. Their points use `[longitude, latitude]`;
their optional extent has a different ordering from a GeoJSON bbox. Do not feed
these documents to Chio's geography-only GeoJSON adapter. Preserve result order
and validate each retained point and label; a malformed response must not become
an empty successful search. Unknown provider fields remain ignorable.

Derive the short name from a valid name or named address component; assemble
supporting address text from the present string components. Missing detail is
empty. Non-string present fields, terminal control characters, missing usable
names or exceeded bounds fail decoding rather than being silently repaired.
Name precedence is `name`, street plus house number, locality, district, city,
county, state, then country. Detail uses street plus house number, locality,
district, postcode plus city, county, state, then country, excluding empty parts
and exact duplicates of the name or an earlier detail component. Fixtures pin
this precedence; it does not infer a permanent identity or modify coordinates.

The internal bounded URLSession transport owns incremental byte limits,
cancellation acknowledgement, same-origin redirects and Linux compatibility.
Its request identity, resource bounds and internal failures are shared; tile
callers retain their existing User-Agent, error mappings, cache policy and
cancellation behavior.
Geocoding requires a JSON MIME type (`application/json` or
`application/geo+json`, allowing parameters); retain the existing tile/catalog
MIME checks, including Foundation's inferred type when a header is absent.
Geocoding requires an explicit Content-Type header. HTTP rejection must retain the
status and a bounded `Retry-After` value before discarding the body. Limit that value to 256 bytes;
invalid or absent retry metadata supplies no retry hint, without hiding the HTTP
status. Map rejection back to the unchanged tile-loader status error for tile
callers. Keep header interpretation and any time-based retry decision outside
the pure result values and never log the rejected response body.
No generic networking package or new SwiftPM dependency is needed. Existing
[static Linux limitations](Dependencies.md#static-linux-blocker) remain.

Per-search limits: at most 512 KiB of decompressed response bytes,
10-second resource deadline, JSON content type, and at most three same-origin
redirects. One transfer-owned deadline spans redirects on both platforms; timeout
cancels the transport and still awaits its terminal acknowledgement. Bound reads
before decoding; Content-Length is not authoritative.
Do not fetch result geometry, paginate, retry, prefetch or persist query history.
An HTTP error, including throttling, is thrown and shown distinctly from no matches.
Preserve useful retry timing when supplied, without starting an automatic retry.
Avoid logging query URLs, response bodies or future provider credentials.

The application owns one active search task and at most one latest pending
submitted query while cancellation drains. A newer submission replaces that
pending value; never create a waiting task or queue entry per submission.
Replacement, Escape, mode changes and teardown invalidate the current publication
generation synchronously, before requesting cancellation or awaiting completion.
Escape, mode changes and teardown also clear the pending submitted query; reopening
search does not revive work from the dismissed interaction.
Start the latest pending request only after the previous operation acknowledges
termination, and only if the search interaction is still active. Publication
checks both generation and the active interaction, including an A → B → A
sequence; comparing query text alone is insufficient. The adapter
does not cancel requests from unrelated consumers. This example enforces its
own submission spacing and can reuse its currently accepted identical query
without another request; it does not claim an application-wide provider quota.

## Example interaction

The existing map example gains a fixture-backed place-search mode. Live tile
acquisition and live search are separate opt-ins: enabling either does not
implicitly enable the other or substitute another data source.

Return in the text field submits; arrows navigate accepted results and Return
opens the selected result. Escape cancels the search interaction and restores
map focus. Highlighting or receiving results alone does not move the map.
One native focus value selects map, field or results. Keep the results list
mounted across loading and empty states, with response-scoped row identities.
Determine initial focus from the accepted rows as well as later response changes:
a fast provider can finish before the search pane first mounts. Accepted nonempty
results focus the native list; an empty or pending interaction focuses the editor.
The map's input path carries batched type-ahead until the native editor receives
focus; the editor then owns editing. Retain explicit bindings and the request
owner in event closures so successive events observe the same storage.
An example-owned enum models idle, loading, matches (including empty) and failed
states with their required query/result/error payloads. Draft text, accepted
map camera and marker state stay with their existing owners.
An example-owned opened-place value retains the accepted place, its credits
and its application-owned marker together. Loading another query, errors, empty
results and Escape must not remove the credits for a marker that remains visible.
Replace or remove that value and its marker/credits together.

Opening a place constructs the new camera and marker/overlays before publishing
them together. It keeps zoom and uses the existing map interaction thereafter.
If a coordinate lies outside the camera's Mercator range, show the location
details and an explicit projection limitation; preserve the previous camera and
marker. Do not silently move that place to a different latitude.

Use the existing native responsive layout and map compact fallback. On narrow
screens, search can replace the map temporarily rather than squeeze both into
unreadable columns. Short search layouts omit map help and selected-place detail
to retain usable result rows and response credits. Credits for the hidden map's
opened marker remain retained and reappear with that map. Keep rows one line with a separate selected-place detail;
give the native results list a finite viewport so measurement and scroll reveal
remain bounded. Row foreground and selected/unselected surfaces use the inherited
Chio style, including the light palette. Do not depend on the pending SwiftTUI
tall-row corrections. Styles change
presentation only. Offline results outside fixture coverage stay honestly outside
coverage; there is no fallback to live tiles.

## Implementation and acceptance order

1. Review this API/provider choice, then add checked values and the provider
   protocol under `Sources/Chio/Maps/Domain` and `Protocol`. Keep pure Photon
   decoding in `Serialization` and its effectful client in `Execution`.
2. Reuse the bounded transport without changing its existing contracts; retain
   tile regressions and add geocoding loopback cases on macOS and Linux.
3. Compose fixture-backed search in `Examples/Maps`; exercise its ownership,
   cancellation, focus, activation and narrow layout through public native APIs.
4. Run pinned engineering checks and required platform/terminal gates. Separately
   probe an explicitly chosen live endpoint with a small public-landmark query.
5. Refresh the map recipe and matching real-terminal showcase assets; verify
   browser controls and deploy only after the implementation PR merges.

Useful regression evidence includes invalid construction/decoding, independent
longitude/latitude expectations, no matches versus failure, preserved order and
duplicates, attribution with empty results, streamed oversize/chunked responses,
bad or missing MIME, unchanged tile MIME acceptance, denied redirects, HTTP 429
with/without valid retry metadata, timeout/cancellation, and cancellation
acknowledgement before replacement. Prove bounded latest-only submission,
stale A → B → A rejection, completion racing Escape/teardown, retained marker
credits across search state changes, and that
style changes, typing, selection and camera movement cause no search requests.
Test explicit activation, projection failure and compact recovery. Reuse the
existing transport fixtures rather than add test-only production interfaces.

## Sources and limits of evidence

Reviewed official documentation on 2026-10-11:

- [Photon API](https://github.com/komoot/photon/blob/master/docs/api-v1.md)
  and [public demo policy](https://github.com/komoot/photon#demo-server).
- [OpenStreetMap attribution and data licensing](https://www.openstreetmap.org/copyright).
- [Nominatim public-instance policy](https://operations.osmfoundation.org/policies/nominatim/)
  and [response/identity contract](https://nominatim.org/release-docs/latest/api/Output/).
- [Geoapify forward geocoding](https://apidocs.geoapify.com/docs/geocoding/forward-geocoding/),
  [terms](https://www.geoapify.com/terms-and-conditions/) and
  [privacy](https://www.geoapify.com/privacy-policy/).

The initial proposal was source/API research only. Implementation and verification
status belongs in [Plan](../Plan.md#next-slice-place-search); neither fixture results
nor a bounded live probe establishes provider availability or search quality.

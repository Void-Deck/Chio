# Submitted routing

**Status:** Approved first service slice merged in
[PR #14](https://github.com/echoz/Chio/pull/14) on 2026-10-13 at `6f3c630`;
not yet in a versioned release. The preceding visual proof is retained under
[MapRouting](../../Spikes/MapRouting/README.md). Provider archive downloads stay paused.

## Boundary and values

`MapRoutingProvider.route(MapRouteRequest)` is an explicit asynchronous operation
beside `MapView`. A request composes an origin and destination `MapCoordinate`;
equal coordinates are permitted. Applications own when to request, provider
choice, cancellation, display identity and camera changes. Tiles, place search
and routing remain independent opt-ins. No navigation engine, turn instructions,
alternatives, automatic rerouting or new renderer is introduced.

`MapRouteResponse` contains an optional `Route` and 1...4 required
`MapAttribution` entries. An absent route means a successful no-route observation;
operation failures are thrown. The nested route composes `MapPolyline` with
optional `distanceMeters` and `durationSeconds`. Unknown estimates remain absent;
zero is known. Present estimates must be finite and nonnegative. Geometry retains
the existing 2...20,000 vertex and distinct-point constraints. These immutable
values are hashable, codable and sendable; decoding preserves construction bounds.

`MapAttribution` shares the existing checked text/link contract. The original
`MapPlaceMatches.Attribution` spelling is a public alias with unchanged JSON keys
and validation. Source consumers rebuild; this is not a binary-compatibility claim.
Credits travel with both routes and no-route responses, separately from tile and
geocoder credits. Applications create an ordinary `MapRoute(id:title:path:)` for
the accepted geometry rather than treating provider observations as UI identities.

The line's endpoints describe the routed geometry, which can start and finish on
nearby roads after provider snapping. Retain the submitted request separately.
Do not stretch the path to requested points or claim it reaches an exact address.
This slice has no provider-independent snapping-radius or travel-mode guarantee.

## OSRM adapter

`OSRMRouter` requires a complete endpoint prefix such as
`https://routing.example/route/v1/driving`, an identifying User-Agent and explicit
service/data attributions. The graph prepared by the operator determines transport
mode; the URL's profile name alone does not. There is no public endpoint default,
credential discovery, history, retry or background prefetch.

Configuration is pure. Shared HTTP validation requires an absolute endpoint up to
2,048 UTF-8 bytes, no credentials/query/fragment/control characters, and HTTPS
except explicit loopback HTTP. Routing also rejects a bare host; reverse-proxy
path prefixes remain supported without guessing the operator’s path schema. User-Agent is nonblank printable ASCII up to 256
bytes. Existing Photon error cases and validation behavior are preserved.

The adapter requests two longitude-first coordinates and one full GeoJSON route:
`geometries=geojson`, `overview=full`, `alternatives=false`, `steps=false`,
`annotations=false`, `generate_hints=false`, `skip_waypoints=true`. It does not
fetch legs, labels or turn instructions. Full geometry is admitted or rejected;
the client never truncates it to fit budgets.

Private decoding requires exactly one LineString for HTTP 200/`Ok`, two ordinates
per position and OSRM's finite nonnegative distance/duration fields. A degenerate
zero-length line reports `unsupportedGeometry`, rather than inventing a route or
misreporting no route. HTTP 400/`NoRoute` is attributed absence; `NoSegment` reports
`cannotSnap`. Other bounded identifier codes are rejected requests. Contradictory
status/code combinations and malformed data fail. Provider messages are ignored.

The existing URLSession owner admits HTTP 400 bodies **only** for routing, because
OSRM carries its failure code in JSON. Both 200 and 400 require an explicit
`application/json` header and at most 2 MiB of decompressed bytes. Other status
codes retain the bounded HTTP status/Retry-After error. Existing tile/catalog and
Photon status/MIME behavior is unchanged. One ten-second resource deadline spans
at most three same-origin redirects; cancellation awaits transport termination.
Each operation owns its transfer and cannot cancel another consumer.

No dependency is added. Existing [static Linux limitations](Dependencies.md#static-linux-blocker)
remain. Application operators remain responsible for endpoint permission, quotas,
privacy, data licensing and appropriate attribution. Tests and showcase recordings
use fixtures; a bounded live probe would establish integration only.

## Example and presentation

The map example owns submitted start/destination coordinates, one active request
and at most one latest pending request. Replacement invalidates publication before
cancelling; the next request starts only after termination acknowledgement. A
generation guard rejects stale A → B → A completions. Clear, scene
change and teardown discard pending work. Typing, panning and style changes do
not request another route.

The fixture demo traces retained road geometry; it is explicitly synthetic, not
a validated driving or walking route, and supplies no invented estimates. The
live router is a separate explicit endpoint option. Requested coordinates stay
distinct from displayed routed endpoints. Pending, no-route and failed states
remain visibly different, with credits retained for an accepted observation.

The approved example treatment mutes geography and uses a bright mint route on
dark styles, dark teal on the light style, and a gold selected endpoint. It scopes
a pure style replacement to the map and reuses native Braille route drawing,
clearance and dot markers. It changes no path geometry or public style API.
All eight dots in a terminal cell still share one foreground. Tight switchbacks
can merge visually; crossings do not communicate direction or elevation. This
is a route overview, not a turn-by-turn navigation display.

## Evidence and sources

Required evidence: checked values and literal compatibility fixtures; independent
coordinate/metric decoding assertions; real loopback status/MIME/body/deadline and
cancellation tests; controlled latest-only ownership tests; native keyboard,
compact recovery, actual terminal captures and default/light/btop inspection.
[Verification](../Verification.md) records commands and evidence limits.

Reviewed on 2026-10-13: [OSRM HTTP API](https://project-osrm.org/docs/v5.24.0/api/),
[operator service summary](https://routing.openstreetmap.de/about.html), and
[OpenStreetMap attribution](https://www.openstreetmap.org/copyright).
The public demo is not a library service commitment. Its full linked legal/privacy
pages were not accessible during research; no blanket live-use authorization is
inferred from the summary.

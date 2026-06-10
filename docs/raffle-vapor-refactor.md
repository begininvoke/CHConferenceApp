# Raffle Refactor: CloudKit → Vapor Backend

Status: **Approved spec, ready for implementation**
Depends on: PR #109 (`mauricio/vapor` — `backend/` Vapor app + `CocoaHeadsCore` shared package)

This document specifies the migration of the live-event raffle feature off CloudKit and
onto the self-hosted Vapor backend, including the realtime protocol, server-side winner
selection, and the client-side service refactor. All product decisions below were
confirmed with the maintainer and are not open questions unless explicitly listed in
[Risks & open items](#risks--open-items).

---

## 1. Why move off CloudKit

The current implementation lives in:

- `CocoaHeadsKit/Sources/CocoaHeadsKit/CloudKit/CloudKit+Raffle.swift` — models + all CloudKit access
- `CocoaHeadsKit/Sources/CocoaHeadsKit/Raffle/RaffleView.swift` — participant card
- `CocoaHeadsKit/Sources/CocoaHeadsKit/Raffle/RaffleStateView.swift` — participant card states
- `CocoaHeadsKit/Sources/CocoaHeadsKit/Raffle/RaffleCreationView.swift` — organizer screen + `RafflePickView` wheel
- Entry point: `EventDetailUI.raffle(slug)` rendered by `EventDetailRenderer` (`RaffleView(id:)`)

Problems this refactor fixes:

1. **Realtime is unreliable.** `CKQuerySubscription` + silent pushes get throttled and
   dropped, which is fatal for a feature whose entire lifetime is ~10 minutes on stage.
2. **The winner is picked on the organizer's phone** (`entries.randomElement()` in
   `RafflePickView.pickWinner()`), then written back to CloudKit, with a hard-coded
   `Task.sleep(for: .seconds(10))` standing in for coordination between the wheel
   animation and the participants' reveal.
3. **iCloud account is required** (`container.userRecordID()` is the participant
   identity). Users without iCloud can't enter, and `RaffleView` is explicitly disabled
   on App Clip and iOS-on-Mac today (`Bundle.main.isAppClip`,
   `isiOSAppOnMac`). The App Clip is exactly where event attendees land.
4. **CloudKit security roles force a write-anything schema** — any user can create
   `RaffleEntry` records freely; dedup is a client-side query.

## 2. Confirmed decisions

| Topic | Decision |
|---|---|
| Backend | The existing Vapor app in `backend/` (Fluent + Postgres, Docker Compose on AWS, deployed via `deploy.sh` / `deploy-backend.yml`) |
| Realtime transport | WebSocket per active raffle screen; REST for request/response actions |
| Winner selection | **Server-side**, single winner per raffle |
| Reveal timing | Server returns the winner to the organizer immediately, **delays the broadcast to participants** by a per-draw `revealDelay` (default 10 s) so the wheel lands before phones light up |
| Redraw | Supported: "winner is absent" → exclude previous winner, draw again (same reveal flow) |
| Participant identity | Client-generated UUID persisted in Keychain (shared access group so App Clip → full app keeps the same identity). No iCloud requirement |
| Anti-abuse | DeviceCheck (`DCDevice`) token sent with entry, validated server-side, **best-effort**: entries without a valid token are still accepted |
| Participant capabilities | Minimal: enter once (immutable name), then watch. No edit, no withdraw, no live count |
| Client architecture | New `RaffleService` protocol injected via SwiftUI `@Environment` (mirroring `cloudKitService`); DTOs live in `CocoaHeadsCore` and are shared verbatim with the backend. **No TCA in this refactor** |
| CloudKit raffle code | Deleted in this refactor. No data migration — past raffles are finished events with no historical value |
| App Clip / Mac | Raffle becomes **enabled** on App Clip and iOS-on-Mac (the iCloud blocker is gone) |

## 3. Shared types (`CocoaHeadsCore`)

New directory `CocoaHeadsCore/Sources/CocoaHeadsCore/Raffle/`, following the
`MeetupEvent`/`ServerDrivenUI` pattern. Everything is `Codable`, `Sendable`,
`Equatable`, platform-free (no CloudKit, no Vapor imports).

```swift
public enum RaffleStatus: String, Codable, Sendable {
  case closed       // exists, not accepting entries (initial state)
  case open         // accepting entries
  case drawing      // winner picked server-side, reveal pending
  case drawn        // winner revealed
}

public struct RaffleDTO: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let slug: String          // e.g. "67sp", referenced by EventDetailUI.raffle
  public let status: RaffleStatus
  public let winner: RaffleEntryDTO?   // nil until status == .drawn
  public let entryCount: Int
}

public struct RaffleEntryDTO: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let raffleID: UUID
  public let participantID: UUID   // client-generated identity
  public let name: String
  public let isVerified: Bool      // DeviceCheck token validated
}

/// Server → client WebSocket messages. One envelope, exhaustive switch on both sides.
public enum RaffleEvent: Codable, Sendable, Equatable {
  case snapshot(RaffleDTO)                 // sent on connect and after reconnect
  case statusChanged(RaffleStatus)         // open/close/drawing transitions
  case entryAdded(RaffleEntryDTO)          // wheel feed; participant UI ignores it
  case winnerRevealed(RaffleEntryDTO)      // sent only at/after revealAt
}

public struct CreateEntryRequest: Codable, Sendable {
  public let participantID: UUID
  public let name: String
  public let deviceToken: String?          // base64 DCDevice token, optional by design
}

public struct DrawRequest: Codable, Sendable {
  public let revealDelaySeconds: Double?   // default 10
}
```

Notes:

- `winner` is intentionally absent from every payload participants can see until
  `status == .drawn`. The `drawing` state is observable (participants can show a
  "sorteando…" treatment later if desired) but never leaks the winner.
- `RaffleEvent` uses Codable enum synthesis (Swift 6 on both sides); no custom
  discriminator plumbing needed.

## 4. Backend (`backend/`)

### 4.1 Fluent models & migration

`raffles`:

| column | type | notes |
|---|---|---|
| `id` | uuid pk | |
| `slug` | text, unique index | lookup key from server-driven UI |
| `status` | text | `RaffleStatus` raw value |
| `winner_entry_id` | uuid fk → raffle_entries, nullable | |
| `reveal_at` | timestamptz, nullable | set when a draw is requested |
| `created_at` / `updated_at` | timestamptz | Fluent timestamps |

`raffle_entries`:

| column | type | notes |
|---|---|---|
| `id` | uuid pk | |
| `raffle_id` | uuid fk, cascade delete | |
| `participant_id` | uuid | |
| `name` | text | |
| `is_verified` | bool | DeviceCheck outcome |
| `device_token_hash` | text, nullable | SHA-256 of the token, for best-effort dedup |
| `is_excluded` | bool, default false | set on redraw ("absent winner") |
| `created_at` | timestamptz | |

Constraints: unique `(raffle_id, participant_id)` — dedup is enforced by the database,
not by a read-then-write like the CloudKit version. A second insert returns the
existing entry (idempotent enter, see 4.2).

### 4.2 REST API

All under `/api/raffles`. Organizer routes guarded by `OrganizerAuthMiddleware`: a
static bearer token from env (`RAFFLE_ADMIN_TOKEN`), entered once in the hidden
organizer UI and stored in the Keychain. This matches the current threat model (the
hidden screens are already the only gate) while removing CloudKit's "anyone can write"
posture; it can be upgraded later without touching the protocol.

| Route | Auth | Behavior |
|---|---|---|
| `POST /api/raffles` `{slug}` | organizer | Create (or return existing — same create-or-fetch semantics as today). Initial status `closed` |
| `GET /api/raffles/:slug` | public | `RaffleDTO` (winner stripped unless `drawn`) |
| `GET /api/raffles/:slug/entries/:participantID` | public | The caller's own entry, 404 if none — restores "already entered" state on fresh launch |
| `POST /api/raffles/:slug/open` / `close` | organizer | Status transitions; broadcast `statusChanged` |
| `POST /api/raffles/:slug/entries` `CreateEntryRequest` | public | 201 with `RaffleEntryDTO`. Rejected with 409 unless status is `open`. Idempotent on `(raffle, participantID)`: re-posting returns the existing entry with 200 |
| `GET /api/raffles/:slug/entries` | organizer | Full entry list (wheel bootstrap) |
| `POST /api/raffles/:slug/draw` `DrawRequest` | organizer | See draw flow |
| `POST /api/raffles/:slug/redraw` `DrawRequest` | organizer | Marks current winner `is_excluded`, then identical to draw |

DeviceCheck validation on entry creation: if `deviceToken` is present, call Apple's
`query_two_bits` endpoint (server credentials via `DEVICECHECK_KEY_ID`,
`DEVICECHECK_TEAM_ID`, `DEVICECHECK_PRIVATE_KEY` env vars). Valid → `is_verified =
true`. Missing token, Apple error, or timeout (cap the call at ~3 s) → entry accepted
with `is_verified = false`. The raffle must never stall because Apple is slow.

### 4.3 Draw flow & state machine

```
closed ──open──► open ──draw──► drawing ──(revealAt elapses)──► drawn
                  ▲                ▲                              │
                  └────────────────┴───────────redraw─────────────┘
```

`POST …/draw`:

1. Require status `open` (or `drawn` for `redraw`). Close entries: status → `drawing`.
2. Pick uniformly at random among entries where `is_excluded == false`
   (`SystemRandomNumberGenerator`). 409 if no eligible entries.
3. Persist `winner_entry_id` and `reveal_at = now + revealDelay` (default 10 s,
   from `DrawRequest`).
4. **Response to the organizer includes the winner immediately** — the wheel needs it
   to aim its deceleration.
5. Broadcast `statusChanged(.drawing)` to all sockets (winner not included).
6. Schedule the reveal: at `reveal_at`, set status `drawn` and broadcast
   `winnerRevealed(entry)`.

Reveal scheduling is a `Task.sleep` inside the actor that owns the raffle's sockets
(see 4.4), **backed by the database**: `reveal_at` is persisted, the WebSocket
`snapshot` is always computed from the DB, and on boot the app transitions any raffle
whose `reveal_at` is in the past to `drawn`. A server restart mid-spin therefore
degrades to "participants see the result on reconnect," never to a stuck `drawing`.

`redraw` re-runs the same flow; the excluded entry stays visible in the organizer's
list but can't win again.

### 4.4 WebSocket

`GET /api/raffles/:slug/live` (Vapor `routes.webSocket`). Public; read-only — clients
never send anything except pings (server also pings every 30 s and drops dead sockets).

- On connect: server sends `snapshot(RaffleDTO)`. Reconnect = reconnect-and-snapshot;
  there is no event replay, the snapshot is the truth.
- Connection registry: one `RaffleHub` actor keyed by raffle ID holding the live
  sockets, responsible for broadcast and for the pending reveal task. Single-instance
  deployment (one container behind Compose) means no cross-node pub/sub is needed;
  if that ever changes, Postgres `LISTEN/NOTIFY` slots in behind the same actor.
- All clients (participants and organizer) receive the same stream. `entryAdded` is
  consumed by the organizer wheel and ignored by the participant card. Names are
  public-by-design (they're projected on stage), so no per-role filtering is needed —
  except the winner, which only ever appears in `winnerRevealed`/post-`drawn`
  snapshots.

### 4.5 Backend tests (`backendTests`, VaporTesting)

- Entry: created when open; 409 when closed/drawing; idempotent re-entry returns the
  same entry; unverified accepted when token invalid/missing.
- State machine: every illegal transition 409s; draw with zero eligible entries 409s.
- Draw: winner persisted; organizer response contains winner; a participant-visible
  `GET` during `drawing` does **not** contain the winner; after `reveal_at`, it does.
- Redraw: previous winner excluded from the candidate set.
- WebSocket: snapshot on connect; `winnerRevealed` not broadcast before `reveal_at`
  (inject a clock/short delay in tests).
- Boot recovery: raffle with past `reveal_at` and status `drawing` becomes `drawn`.

## 5. Client refactor (`CocoaHeadsKit`)

### 5.1 `RaffleService` protocol

New `CocoaHeadsKit/Sources/CocoaHeadsKit/Raffle/RaffleService.swift`:

```swift
public protocol RaffleService: Sendable {
  // Participant
  func raffle(slug: String) async throws -> RaffleDTO
  func myEntry(slug: String) async throws -> RaffleEntryDTO?
  func enter(slug: String, name: String) async throws -> RaffleEntryDTO
  func events(slug: String) -> AsyncThrowingStream<RaffleEvent, any Error>

  // Organizer (hidden screens)
  func createRaffle(slug: String) async throws -> RaffleDTO
  func setOpen(_ open: Bool, slug: String) async throws -> RaffleDTO
  func entries(slug: String) async throws -> [RaffleEntryDTO]
  func draw(slug: String, revealDelay: Duration) async throws -> RaffleEntryDTO
  func redraw(slug: String, revealDelay: Duration) async throws -> RaffleEntryDTO
}
```

Injected via `@Environment(\.raffleService)` exactly like `cloudKitService`.
Implementations:

- **`LiveRaffleService`** — `URLSession` for REST, `URLSessionWebSocketTask` for
  `events(slug:)` with automatic reconnect (exponential backoff, resubscribe →
  snapshot). Base URL from a single `BackendConfiguration` (Debug → local/staging,
  Release → production host); reuse PR #109's configuration if it already defines one
  rather than introducing a second.
  - `enter` gathers the DeviceCheck token via `DCDevice.current.generateToken()` with
    a short timeout; failure → send `deviceToken: nil` (decision: never block entry).
  - `participantID`: lazily created `UUID`, stored in the shared Keychain access
    group (add the access group to `NSClip` and app entitlements) so the App Clip and
    the full app are the same entrant.
  - Organizer admin token: stored in Keychain, set from a field on the organizer
    screen.
- **`MockRaffleService`** — in-memory, scriptable; used by previews and tests. This is
  the testability win the TODO list has been asking for.

### 5.2 View changes

- **`RaffleView`** (participant): same `RaffleState` view-state enum and
  `RaffleStateView` UI, but state is derived from `RaffleDTO.status` + `myEntry`
  instead of CloudKit fetches, and updates flow from `events(slug:)`. Remove the
  `isiOSAppOnMac` / `isAppClip` / iCloud guards — the feature now works everywhere.
  `submitted → winner/loser` flips when `winnerRevealed` arrives (server-timed, so the
  room and the phones agree).
- **`RafflePickView`** (organizer wheel): `pickWinner()` becomes: call
  `draw(slug:revealDelay: .seconds(10))` → receive winner immediately → stop the
  `repeatForever` spin and run a single decelerating rotation computed to land the
  winner's segment at the marker over the same 10 s. Delete the `Task.sleep(10)`.
  Entry feed comes from `entryAdded` events instead of `listenToEntries`. Add a
  "Sortear novamente (ganhador ausente)" button wired to `redraw`.
- **`RaffleCreationView`**: same flow against `createRaffle`/`setOpen` (the `Live`
  toggle currently bound to `.constant` becomes functional), plus the admin-token
  field.
- **Deletions**: `CloudKit+Raffle.swift` entirely; `cloudKitRemoteNotificationReceived`
  raffle observers; the `Raffle`/`RaffleEntry` structs (replaced by Core DTOs).
  `EventDetailUI.raffle(String)` and the renderer call site are unchanged — slugs keep
  coming from server-driven pages.

### 5.3 Client tests (`CocoaHeadsKitTests`)

- `RaffleState` derivation matrix: (status × hasEntry × isWinner) → expected state,
  driven through `MockRaffleService`.
- Reconnect behavior: stream that errors then resumes yields a fresh snapshot and the
  view converges.
- `LiveRaffleService` decoding round-trips for every `RaffleEvent` case against fixture
  JSON (shared fixtures with backend tests via `CocoaHeadsCore` test target keeps the
  protocol honest).

## 6. Rollout

1. Land PR #109 (backend skeleton + `CocoaHeadsCore`).
2. Backend raffle module + tests; deploy to the AWS box via the existing workflow.
3. **Infra prerequisite:** the Compose stack serves plain HTTP on :8080. ATS and
   `wss://` require TLS — put Caddy (or nginx + certbot) in front with a real
   hostname before any TestFlight build points at it.
4. Client refactor behind the same TestFlight cycle; organizer dry-runs a full raffle
   (open → enter from App Clip + full app → draw → redraw) at a chapter meetup before
   conference day.
5. After the dry-run, delete the CloudKit `Raffle`/`RaffleEntry` record types from the
   CloudKit dashboard at leisure; nothing references them.

## 7. Risks & open items

- **DeviceCheck in App Clips**: App Attest is documented as unavailable in App Clips;
  plain `DCDevice` token generation is expected to work but must be verified on a real
  device during step 4. The design already tolerates the worst case (token absent →
  unverified entry), so this is a verification task, not a blocker.
- **Admin token is a shared static secret.** Acceptable for the current threat model
  and rotateable via env + redeploy; revisit if organizer tooling grows.
- **Single-instance assumption** for the WebSocket hub (documented in 4.4). Fine for
  one conference; the Postgres `LISTEN/NOTIFY` upgrade path is noted.
- **Wheel/winner sync depends on client clock only relatively** (it animates for the
  same `revealDelay` the server uses); network latency on the draw response slightly
  shortens the wheel's runway. Use the response's `reveal_at` minus local now as the
  animation duration to absorb it.

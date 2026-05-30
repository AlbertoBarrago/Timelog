# Synchronisation

The project uses two separate sync implementations, one per platform, both in the `TimelogSync` package.

| Platform | Service | Protocol |
|----------|---------|----------|
| iOS | `RestSyncService` | URLSession → Vercel Functions → MongoDB Atlas |
| macOS | `MongoSyncService` | MongoKitten → MongoDB Atlas (direct wire protocol) |

---

## iOS — RestSyncService

### Architecture

```mermaid
flowchart TD
    subgraph iOS["iOS App"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain\nrest_sync_server_url\nrest_sync_api_key")]
        File["SyncConfig.local\n(bundle, gitignored)"]
        RSS["RestSyncService\n@Observable @MainActor"]
    end

    subgraph Vercel["Vercel Functions"]
        Pull["GET /api/pull"]
        Sync["POST /api/sync"]
    end

    MDB[("MongoDB Atlas")]

    File -->|"loadConfigFromFile()\nif Keychain empty"| KCH
    KCH --> RSS

    MDB -->|"pullAll(into:)\non app launch"| Pull
    Pull -->|"{ clients, projects, entries, sessions }"| RSS
    RSS -->|"upsert by mongoId"| SD

    SD -->|"onChange + debounce 2s"| RSS
    RSS -->|"POST payload"| Sync
    Sync -->|"upsert"| MDB
```

### Launch sequence

1. `loadConfigFromFile()` — reads `SyncConfig.local` from the bundle (URL + API_KEY), saves to Keychain if not already configured
2. `setDataProvider` — registers the closure that fetches all data from `container.mainContext`
3. `isPulling = true` — blocks push during pull to prevent loops
4. `pullAll(into:)`:
   - GET `/api/pull?userId=…` with `X-API-Key` header (the server scopes the response per user; the client also filters on receipt)
   - Upsert by `mongoId` in order: clients → projects → entries → sessions, linking relationships in memory
   - Existing records are updated in place; new records are inserted; soft-deleted records (`deletedAt`) are applied but never inserted fresh
   - Sessions use a replace strategy scoped to `userId`
5. `isPulling = false` — `SyncFlashOverlay` shows green flash + haptic

### Auto-push

`onChange` on clients/projects/entries/sessions → `triggerSync()` (only if `!isPulling`) → debounce 2s → POST `/api/sync`

The push payload carries a top-level `userId`. The server upserts every collection and then **reconciles sessions**: any `active_sessions` document for that `userId` not present in the payload is deleted, so a session stopped on one device does not reappear as a "ghost" on the next pull.

> **userId filtering (RestSyncService)**: DTOs sent to and received from Vercel Functions include `userId`. On pull, `RestSyncService` filters the returned records client-side, keeping only those where `userId == settings.userId` (or where `userId` is absent/empty for legacy records). On push, each serialised document includes the current `settings.userId`.

### Configuration

```bash
# Timelog/SyncConfig.local (gitignored, included in iOS bundle)
URL=https://your-app.vercel.app
API_KEY=your-secret-key
```

### Observable state

| Property | Type | Meaning |
|----------|------|---------|
| `isSyncing` | `Bool` | Pull or push in progress |
| `lastSyncDate` | `Date?` | Timestamp of last successful sync |
| `lastError` | `String?` | Last error (nil if OK) |
| `isConfigured` | `Bool` | URL and API key present in Keychain |

---

## macOS — MongoSyncService

### Architecture

```mermaid
flowchart TD
    subgraph macOS["macOS App"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain\nmongo_connection_string")]
        File["~/.config/timelog/mongo.local\n(outside repo, dev only)"]
        MSS["MongoSyncService\n@Observable @MainActor"]
    end

    subgraph MongoDB["MongoDB Atlas"]
        DB[("Database: timelog")]
        C1["clients"]
        C2["projects"]
        C3["time_entries"]
    end

    File -->|"loadConnectionStringFromFile()\nif Keychain empty"| KCH
    KCH -->|"connect()"| MSS

    MongoDB -->|"pullAll(into:)\nif SwiftData empty"| MSS
    MSS -->|"upsert into SwiftData"| SD

    SD -->|"NSManagedObjectContextDidSave\n+ triggerSync()"| MSS
    MSS -->|"upsertEncoded — push"| MongoDB

    C1 & C2 & C3 --- DB
```

### Launch sequence

1. `loadConnectionStringFromFile()` — reads `~/.config/timelog/mongo.local`, saves to Keychain if empty
2. `connect()` — opens the wire-protocol connection via MongoKitten
3. `pullAll(into:)` — executed **only if SwiftData is empty** (first launch or after manual reset), to avoid an empty-state flash
4. `triggerSync()` — immediate push of local data to Atlas

### Auto-push

`onChange` on clients/projects/entries → `triggerSync()` → debounce 2s → `upsertEncoded` on all three collections

> **userId filtering (MongoSyncService)**: all MongoDB queries include a `"userId" == userId` filter at the driver level, so only the current user's documents are fetched. Each document pushed via `upsertEncoded` includes the `userId` field. This means MongoSyncService never reads or overwrites another user's data even on a shared Atlas cluster.

### Configuration

```bash
mkdir -p ~/.config/timelog
echo "mongodb+srv://user:password@cluster.mongodb.net" > ~/.config/timelog/mongo.local
```

**Read priority:**
```
~/.config/timelog/mongo.local  (only if Keychain is empty)
         ↓
  Keychain "mongo_connection_string"
         ↓
    MongoSyncService.db
```

### Observable state

| Property | Type | Meaning |
|----------|------|---------|
| `isSyncing` | `Bool` | Pull or push in progress |
| `lastSyncDate` | `Date?` | Timestamp of last successful pull or push |
| `lastError` | `String?` | Last error (nil if OK) |

---

## MongoDB document schema (shared)

Documents are identical regardless of which platform wrote them (iOS via Vercel, macOS via MongoKitten).

### `clients`
```json
{ "_id": ObjectId("..."), "name": "Acme", "colorHex": "#FF5733", "isArchived": false, "userId": "alice", "deletedAt": null }
```

### `projects`
```json
{ "_id": ObjectId("..."), "name": "Website", "code": "PRJ-01", "labels": ["frontend"], "clientMongoId": "64abc...", "userId": "alice", "deletedAt": null }
```
> `projects` have no `isArchived` flag — only `clients` are archivable.

### `time_entries`
```json
{ "_id": ObjectId("..."), "date": "2025-05-15T09:00:00.000Z", "durationMinutes": 90, "notes": "...", "label": "...", "clientMongoId": "...", "projectMongoId": "...", "userId": "alice", "deletedAt": null }
```

### `active_sessions` (ActiveSession)
```json
{ "_id": ObjectId("..."), "startDate": "2025-05-15T09:00:00.000Z", "notes": "...", "label": "...", "clientMongoId": "...", "projectMongoId": "...", "notificationID": "...", "userId": "alice" }
```

> **`deletedAt` note**: applies to `clients`, `projects` and `time_entries` only. It is `null` for active records and set to the deletion date for logically deleted ones; the value is propagated on pull (rows are kept locally and hidden by `deletedAt`-filtered `@Query`s, not hard-deleted). `active_sessions` have no `deletedAt`: a stopped session is hard-deleted and reconciled server-side per `userId`.

> **`userId` note**: every document written by either platform includes a `userId` field containing the owner's nickname (from `SettingsStore.userId`). This enables multiple users to share a single MongoDB database without their data colliding. Legacy documents with a missing or empty `userId` are treated as nil-tolerant by `RestSyncService` (iOS) and are still visible to the user; `MongoSyncService` (macOS) filters at query time so they are simply not returned. A compound index on `{ userId: 1, _id: 1 }` is recommended for each collection to keep per-user queries efficient.

---

## MongoId strategy

Every SwiftData entity has a `mongoId: String?` field used as the sync key by both implementations.

| Scenario | iOS (RestSyncService) | macOS (MongoSyncService) |
|----------|-----------------------|--------------------------|
| Pull — document found by mongoId | Update fields in-place | Update fields in-place |
| Pull — document not found | Create new entity with mongoId = server `_id` | Create new entity with mongoId = server `_id` |
| Push — `mongoId` present | Use as `_id` for upsert | Use as `ObjectId` for upsert |
| Push — `mongoId` absent | Leave empty (`""`) — server generates a new `_id` | Generate a new valid `ObjectId` |

> **iOS note**: pull is an incremental upsert keyed by `mongoId` (existing rows updated in place, new rows inserted). Sessions use a replace strategy scoped to `userId`; Client/Project/TimeEntry rely on soft delete (`deletedAt`) rather than removal.

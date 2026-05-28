import Foundation
import SwiftData
import TimelogCore

public enum MongoSyncError: LocalizedError {
    case noCredentials
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .noCredentials: return "Connection string not found in Keychain."
        case .notConnected:  return "Not connected to MongoDB."
        }
    }
}

#if os(macOS)
import MongoKitten

private struct ClientDocument: Codable {
    var _id: ObjectId
    var name: String
    var colorHex: String
    var isArchived: Bool
    var userId: String
    var deletedAt: Date?
    init(from client: Client) {
        _id = client.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        name = client.name; colorHex = client.colorHex; isArchived = client.isArchived
        userId = client.userId; deletedAt = client.deletedAt
    }
}

private struct ProjectDocument: Codable {
    var _id: ObjectId
    var name: String
    var code: String?
    var userId: String
    var clientMongoId: String?
    var labels: [String]
    var deletedAt: Date?

    init(from project: TimelogCore.Project) {
        _id = project.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        name = project.name; code = project.code
        userId = project.userId; clientMongoId = project.client?.mongoId
        labels = project.labels
        deletedAt = project.deletedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _id           = try c.decode(ObjectId.self, forKey: ._id)
        name          = try c.decode(String.self, forKey: .name)
        code          = try c.decodeIfPresent(String.self, forKey: .code)
        userId        = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        clientMongoId = try c.decodeIfPresent(String.self, forKey: .clientMongoId)
        labels        = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        deletedAt     = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

private struct TimeEntryDocument: Codable {
    var _id: ObjectId
    var date: Date
    var durationMinutes: Int
    var notes: String?
    var label: String?
    var userId: String
    var clientMongoId: String?
    var projectMongoId: String?
    var deletedAt: Date?
    init(from entry: TimeEntry) {
        _id = entry.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        date = entry.date; durationMinutes = entry.durationMinutes; notes = entry.notes
        label = entry.label
        userId = entry.userId
        clientMongoId = entry.client?.mongoId; projectMongoId = entry.project?.mongoId
        deletedAt = entry.deletedAt
    }
}

private struct ActiveSessionDocument: Codable {
    var _id: ObjectId
    var startDate: Date
    var notes: String?
    var label: String?
    var userId: String
    var clientMongoId: String?
    var projectMongoId: String?
    var notificationID: String
    init(from session: ActiveSession) {
        _id = session.mongoId.flatMap { ObjectId($0) } ?? ObjectId()
        startDate = session.startDate; notes = session.notes; label = session.label
        userId = session.userId
        clientMongoId = session.client?.mongoId; projectMongoId = session.project?.mongoId
        notificationID = session.notificationID
    }
}

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()
    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession])

    private var db: MongoDatabase?
    private var dataProvider: DataProvider?
    private var debounceTask: Task<Void, Never>?

    public var userId: String = ""

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    public var isUserEditing = false {
        didSet {
            guard !isUserEditing, pendingSyncRequested else { return }
            pendingSyncRequested = false
            scheduleDebounced()
        }
    }
    private var pendingSyncRequested = false

    public static let willWipeDataNotification = Notification.Name("MongoSyncServiceWillWipeData")
    private static let connectionStringKey = "mongo_connection_string"
    private static let debounceSeconds: Double = 2

    private init() {}

    public func saveConnectionString(_ s: String) { KeychainHelper.save(key: Self.connectionStringKey, value: s) }
    public func readConnectionString() -> String?  { KeychainHelper.read(key: Self.connectionStringKey) }

    public func loadConnectionStringFromFile() {
        guard readConnectionString() == nil else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/timelog/mongo.local")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveConnectionString(trimmed)
    }

    public func connect() async throws {
        guard let raw = KeychainHelper.read(key: Self.connectionStringKey) else { throw MongoSyncError.noCredentials }
        db = try await MongoDatabase.connect(to: resolvedConnectionString(raw))
    }

    private func resolvedConnectionString(_ raw: String) -> String {
        guard var c = URLComponents(string: raw) else { return raw }
        if c.path.isEmpty || c.path == "/" { c.path = "/timelog" }
        return c.string ?? raw
    }

    public func setDataProvider(_ provider: @escaping DataProvider) { dataProvider = provider }

    public func triggerSync() { scheduleDebounced() }

    public func triggerSyncNow() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            if self.db == nil {
                do { try await self.connect() } catch { self.lastError = error.localizedDescription; return }
            }
            guard let data = self.dataProvider?() else { return }
            try? await self.syncAll(clients: data.clients, projects: data.projects, entries: data.entries, sessions: data.sessions)
        }
    }

    public func stopAutoSync() { debounceTask?.cancel(); dataProvider = nil }

    private func scheduleDebounced() {
        guard !isUserEditing else { pendingSyncRequested = true; return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceSeconds))
            guard !Task.isCancelled, let self else { return }
            if self.db == nil {
                do { try await self.connect() } catch is CancellationError {
                    return
                } catch { self.lastError = error.localizedDescription; return }
            }
            guard let data = self.dataProvider?() else { return }
            do {
                try await self.syncAll(clients: data.clients, projects: data.projects, entries: data.entries, sessions: data.sessions)
            } catch is CancellationError {
                // superseded by a newer sync request — not an error
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession]) async throws {
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true; lastError = nil; defer { isSyncing = false }
        do {
            try await push(clients: clients, to: db)
            try await push(projects: projects, to: db)
            try await push(entries: entries, to: db)
            try await push(sessions: sessions, to: db)
            lastSyncDate = .now
        } catch { lastError = error.localizedDescription; throw error }
    }

    public func pullAll(into context: ModelContext) async throws {
        guard !isUserEditing else { return }
        guard let db else { throw MongoSyncError.notConnected }
        isSyncing = true; lastError = nil; defer { isSyncing = false }
        do {
            let clientMap = try await pull(clientsInto: context, from: db)
            let projectMap = try await pull(projectsInto: context, from: db, clientMap: clientMap)
            try await pull(entriesInto: context, from: db, clientMap: clientMap, projectMap: projectMap)
            try await pull(sessionsInto: context, from: db, clientMap: clientMap, projectMap: projectMap)
            try context.save()
            lastSyncDate = .now
        } catch { lastError = error.localizedDescription; throw error }
    }

    private func pull(clientsInto ctx: ModelContext, from db: MongoDatabase) async throws -> [String: Client] {
        let docs = try await db["clients"].find("userId" == userId).decode(ClientDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        let allLocalClients = (try? ctx.fetch(FetchDescriptor<Client>())) ?? []
        let myLocalClients = allLocalClients.filter { $0.userId == userId }
        var localById = Dictionary(uniqueKeysWithValues: myLocalClients.compactMap { c in c.mongoId.map { ($0, c) } })
        for doc in docs {
            let id = doc._id.hexString
            if let c = localById[id] {
                c.name = doc.name; c.colorHex = doc.colorHex; c.isArchived = doc.isArchived
                c.deletedAt = doc.deletedAt
            } else if doc.deletedAt == nil {
                let c = Client(name: doc.name, colorHex: doc.colorHex, isArchived: doc.isArchived, userId: userId)
                c.mongoId = id; ctx.insert(c); localById[id] = c
            }
        }
        for client in myLocalClients {
            if let mid = client.mongoId, !remoteIds.contains(mid) { ctx.delete(client) }
        }
        return localById
    }

    private func pull(projectsInto ctx: ModelContext, from db: MongoDatabase, clientMap: [String: Client]) async throws -> [String: TimelogCore.Project] {
        let docs = try await db["projects"].find("userId" == userId).decode(ProjectDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        let allLocalProjects = (try? ctx.fetch(FetchDescriptor<TimelogCore.Project>())) ?? []
        let myLocalProjects = allLocalProjects.filter { $0.userId == userId }
        var localById = Dictionary(uniqueKeysWithValues: myLocalProjects.compactMap { p in p.mongoId.map { ($0, p) } })
        for doc in docs {
            let id = doc._id.hexString
            if let p = localById[id] {
                p.name = doc.name; p.code = doc.code
                p.labels = doc.labels
                p.deletedAt = doc.deletedAt
            } else if doc.deletedAt == nil {
                let p = TimelogCore.Project(name: doc.name, code: doc.code, userId: userId)
                p.mongoId = id
                p.labels = doc.labels
                if let cid = doc.clientMongoId { p.client = clientMap[cid] }
                ctx.insert(p); localById[id] = p
            }
        }
        for project in myLocalProjects {
            if let mid = project.mongoId, !remoteIds.contains(mid) { ctx.delete(project) }
        }
        return localById
    }

    private func pull(entriesInto ctx: ModelContext, from db: MongoDatabase, clientMap: [String: Client], projectMap: [String: TimelogCore.Project]) async throws {
        let docs = try await db["time_entries"].find("userId" == userId).decode(TimeEntryDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        let allLocalEntries = (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? []
        let myLocalEntries = allLocalEntries.filter { $0.userId == userId }
        let localById = Dictionary(uniqueKeysWithValues: myLocalEntries.compactMap { e in e.mongoId.map { ($0, e) } })
        for doc in docs {
            let id = doc._id.hexString
            if let e = localById[id] {
                e.date = doc.date; e.durationMinutes = doc.durationMinutes; e.notes = doc.notes
                e.label = doc.label
                e.deletedAt = doc.deletedAt
            } else if doc.deletedAt == nil {
                let client = doc.clientMongoId.flatMap { clientMap[$0] }
                let project = doc.projectMongoId.flatMap { projectMap[$0] }
                let e = TimeEntry(date: doc.date, durationMinutes: doc.durationMinutes, notes: doc.notes, label: doc.label, client: client, project: project, userId: userId)
                e.mongoId = id; ctx.insert(e)
            }
        }
        for entry in myLocalEntries {
            if let mid = entry.mongoId, !remoteIds.contains(mid) { ctx.delete(entry) }
        }
    }

    private func push(clients: [Client], to db: MongoDatabase) async throws {
        let col = db["clients"]
        for c in clients { let doc = ClientDocument(from: c); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }

    private func push(projects: [TimelogCore.Project], to db: MongoDatabase) async throws {
        let col = db["projects"]
        for p in projects { let doc = ProjectDocument(from: p); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }

    private func push(entries: [TimeEntry], to db: MongoDatabase) async throws {
        let col = db["time_entries"]
        for e in entries { let doc = TimeEntryDocument(from: e); try await col.upsertEncoded(doc, where: "_id" == doc._id) }
    }

    private func push(sessions: [ActiveSession], to db: MongoDatabase) async throws {
        let col = db["active_sessions"]
        let localIds = Set(sessions.compactMap { $0.mongoId })
        for s in sessions {
            let doc = ActiveSessionDocument(from: s)
            try await col.upsertEncoded(doc, where: "_id" == doc._id)
        }
        // Delete remote sessions no longer present locally (e.g. stopped on this device)
        let remoteDocs = try await col.find().decode(ActiveSessionDocument.self).drain()
        for remote in remoteDocs where !localIds.contains(remote._id.hexString) {
            try await col.deleteAll(where: "_id" == remote._id)
        }
    }

    private func pull(sessionsInto ctx: ModelContext, from db: MongoDatabase, clientMap: [String: Client], projectMap: [String: TimelogCore.Project]) async throws {
        let docs = try await db["active_sessions"].find("userId" == userId).decode(ActiveSessionDocument.self).drain()
        let remoteIds = Set(docs.map { $0._id.hexString })
        let allLocal = (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
        let myLocal = allLocal.filter { $0.userId == userId }
        let localById = Dictionary(uniqueKeysWithValues: myLocal.compactMap { s in s.mongoId.map { ($0, s) } })
        for doc in docs {
            let id = doc._id.hexString
            if let s = localById[id] {
                s.startDate = doc.startDate; s.notes = doc.notes; s.label = doc.label
            } else {
                let s = ActiveSession(
                    client: doc.clientMongoId.flatMap { clientMap[$0] },
                    project: doc.projectMongoId.flatMap { projectMap[$0] },
                    notes: doc.notes, label: doc.label, userId: userId
                )
                s.startDate = doc.startDate
                s.mongoId = id
                s.notificationID = doc.notificationID
                ctx.insert(s)
            }
        }
        for local in myLocal {
            if let mid = local.mongoId, !remoteIds.contains(mid) {
                NotificationManager.shared.cancelSession(id: local.notificationID)
                ctx.delete(local)
            }
        }
    }
}

#else

// MARK: - iOS no-op stub

@Observable
@MainActor
public final class MongoSyncService {
    public static let shared = MongoSyncService()
    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession])

    public var userId: String = ""

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?
    public static let willWipeDataNotification = Notification.Name("MongoSyncServiceWillWipeData")
    private static let connectionStringKey = "mongo_connection_string"

    private init() {}

    public func saveConnectionString(_ s: String) { KeychainHelper.save(key: Self.connectionStringKey, value: s) }
    public func readConnectionString() -> String?  { KeychainHelper.read(key: Self.connectionStringKey) }
    public func loadConnectionStringFromFile() {}
    public func connect() async throws {}
    public func setDataProvider(_ provider: @escaping DataProvider) {}
    public func triggerSync() {}
    public func triggerSyncNow() {}
    public func stopAutoSync() {}
    public func syncAll(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession]) async throws {}
    public func pullAll(into context: ModelContext) async throws {}
}

#endif

import Foundation
import SwiftData
import TimelogCore

// MARK: - Errors

public enum RestSyncError: LocalizedError {
    case httpError(Int, String)
    public var errorDescription: String? {
        if case .httpError(let code, let body) = self { return "HTTP \(code): \(body)" }
        return nil
    }
}

// MARK: - DTOs

private struct PullResponse: Decodable {
    var clients:  [ClientDTO]
    var projects: [ProjectDTO]
    var entries:  [EntryDTO]
    var sessions: [SessionDTO]
}

private struct SessionDTO: Codable {
    var _id: String
    var startDate: String?
    var notes: String?
    var label: String?
    var userId: String?
    var clientMongoId: String?
    var projectMongoId: String?
    var notificationID: String?
}

private struct ClientDTO: Codable {
    var _id: String
    var name: String
    var colorHex: String?
    var isArchived: Bool?
    var userId: String?
    var deletedAt: String?
}

private struct ProjectDTO: Codable {
    var _id: String
    var name: String
    var code: String?
    var userId: String?
    var clientMongoId: String?
    var labels: [String]?
    var deletedAt: String?
}

private struct EntryDTO: Codable {
    var _id: String
    var date: String?
    var durationMinutes: Int?
    var notes: String?
    var label: String?
    var userId: String?
    var clientMongoId: String?
    var projectMongoId: String?
    var deletedAt: String?
}

private struct SyncPayload: Encodable {
    var clients:  [ClientDTO]
    var projects: [ProjectDTO]
    var entries:  [EntryDTO]
    var sessions: [SessionDTO]
}

// MARK: - Service

@Observable
@MainActor
public final class RestSyncService {
    public static let shared = RestSyncService()

    public typealias DataProvider = () -> (clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession])

    private var dataProvider: DataProvider?
    private var debounceTask: Task<Void, Never>?

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: String?

    private static let serverURLKey = "rest_sync_server_url"
    private static let apiKeyKey    = "rest_sync_api_key"
    private static let debounceSeconds: Double = 2

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public var userId: String = ""

    private init() {}

    // MARK: - Config (Keychain)

    public func saveConfig(serverURL: String, apiKey: String) {
        KeychainHelper.save(key: Self.serverURLKey, value: serverURL)
        KeychainHelper.save(key: Self.apiKeyKey, value: apiKey)
    }

    public func readServerURL() -> String? { KeychainHelper.read(key: Self.serverURLKey) }
    public func readApiKey()    -> String? { KeychainHelper.read(key: Self.apiKeyKey) }

    public var isConfigured: Bool { readServerURL() != nil && readApiKey() != nil }

    /// macOS: legge ~/.config/timelog/sync.local
    /// iOS:   legge SyncConfig.local dal bundle (gitignored, mai pushato)
    /// Sovrascrive sempre il Keychain — aggiornare il file per cambiare URL o API key.
    public func loadConfigFromFile() {
        #if os(macOS)
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/timelog/sync.local")
        #else
        guard let fileURL = Bundle.main.url(forResource: "SyncConfig", withExtension: "local") else { return }
        #endif
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        var serverURL: String?
        var apiKey: String?
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0].trimmingCharacters(in: .whitespaces) {
            case "URL":     serverURL = parts[1].trimmingCharacters(in: .whitespaces)
            case "API_KEY": apiKey    = parts[1].trimmingCharacters(in: .whitespaces)
            default: break
            }
        }
        if let u = serverURL, let k = apiKey, !u.isEmpty, !k.isEmpty {
            saveConfig(serverURL: u, apiKey: k)
        }
    }

    // MARK: - Sync control

    public func setDataProvider(_ provider: @escaping DataProvider) { dataProvider = provider }

    public func triggerSync() { scheduleDebounced() }

    public func triggerSyncNow() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self, let data = self.dataProvider?() else { return }
            do {
                try await self.push(clients: data.clients, projects: data.projects, entries: data.entries, sessions: data.sessions)
            } catch is CancellationError {
                // superseded by a newer sync request — not an error
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    public func stopAutoSync() { debounceTask?.cancel(); dataProvider = nil }

    private func scheduleDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceSeconds))
            guard !Task.isCancelled, let self else { return }
            guard let data = self.dataProvider?() else { return }
            do {
                try await self.push(clients: data.clients, projects: data.projects, entries: data.entries, sessions: data.sessions)
            } catch is CancellationError {
                // superseded by a newer sync request — not an error
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Pull (server → SwiftData)

    public func pullAll(into context: ModelContext) async throws {
        guard let url = serverURL(path: "/api/pull") else { return }
        isSyncing = true; lastError = nil; defer { isSyncing = false }

        let response: PullResponse
        do {
            response = try await get(url: url)
        } catch {
            lastError = error.localizedDescription
            throw error
        }

        let existingClients = (try? context.fetch(FetchDescriptor<Client>())) ?? []
        var clientMap: [String: Client] = Dictionary(uniqueKeysWithValues: existingClients.compactMap { c in c.mongoId.map { ($0, c) } })
        for dto in response.clients where dto.userId == nil || dto.userId == userId {
            let deletedAt = dto.deletedAt.flatMap { Self.iso8601.date(from: $0) ?? Self.iso8601NoFrac.date(from: $0) }
            if let c = clientMap[dto._id] {
                c.name = dto.name
                c.colorHex = dto.colorHex ?? c.colorHex
                c.isArchived = dto.isArchived ?? c.isArchived
                c.deletedAt = deletedAt
            } else if deletedAt == nil {
                let c = Client(name: dto.name, colorHex: dto.colorHex ?? "#007AFF", isArchived: dto.isArchived ?? false, userId: userId)
                c.mongoId = dto._id; c.deletedAt = deletedAt
                context.insert(c); clientMap[dto._id] = c
            }
        }
        let existingProjects = (try? context.fetch(FetchDescriptor<TimelogCore.Project>())) ?? []
        var projectMap: [String: TimelogCore.Project] = Dictionary(uniqueKeysWithValues: existingProjects.compactMap { p in p.mongoId.map { ($0, p) } })
        for dto in response.projects where dto.userId == nil || dto.userId == userId {
            let deletedAt = dto.deletedAt.flatMap { Self.iso8601.date(from: $0) ?? Self.iso8601NoFrac.date(from: $0) }
            if let p = projectMap[dto._id] {
                p.name = dto.name; p.code = dto.code
                p.labels = dto.labels ?? p.labels
                p.deletedAt = deletedAt
                if let cid = dto.clientMongoId { p.client = clientMap[cid] }
            } else if deletedAt == nil {
                let p = TimelogCore.Project(name: dto.name, code: dto.code, userId: userId)
                p.mongoId = dto._id
                p.labels = dto.labels ?? []
                if let cid = dto.clientMongoId { p.client = clientMap[cid] }
                context.insert(p); projectMap[dto._id] = p
            }
        }
        let existingEntries = (try? context.fetch(FetchDescriptor<TimeEntry>())) ?? []
        let entryMap: [String: TimeEntry] = Dictionary(uniqueKeysWithValues: existingEntries.compactMap { e in e.mongoId.map { ($0, e) } })
        for dto in response.entries {
            let dateStr = dto.date ?? ""
            let date = Self.iso8601.date(from: dateStr) ?? Self.iso8601NoFrac.date(from: dateStr) ?? Date()
            let deletedAt = dto.deletedAt.flatMap { Self.iso8601.date(from: $0) ?? Self.iso8601NoFrac.date(from: $0) }
            guard dto.userId == nil || dto.userId == userId else { continue }
            if let e = entryMap[dto._id] {
                e.date = date; e.durationMinutes = dto.durationMinutes ?? e.durationMinutes
                e.notes = dto.notes; e.label = dto.label; e.deletedAt = deletedAt
            } else if deletedAt == nil {
                let e = TimeEntry(date: date, durationMinutes: dto.durationMinutes ?? 0, notes: dto.notes,
                                  label: dto.label,
                                  client: dto.clientMongoId.flatMap { clientMap[$0] },
                                  project: dto.projectMongoId.flatMap { projectMap[$0] },
                                  userId: userId)
                e.mongoId = dto._id; context.insert(e)
            }
        }
        // Sessions: replace strategy (remote is authoritative)
        let allLocalSessions = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        let localSessionById = Dictionary(uniqueKeysWithValues: allLocalSessions.compactMap { s in s.mongoId.map { ($0, s) } })
        let remoteSessionIds = Set(response.sessions.map { $0._id })
        for dto in response.sessions {
            let startDate = dto.startDate.flatMap { Self.iso8601.date(from: $0) ?? Self.iso8601NoFrac.date(from: $0) } ?? Date()
            if let s = localSessionById[dto._id] {
                s.startDate = startDate; s.notes = dto.notes; s.label = dto.label
            } else {
                let s = ActiveSession(
                    client: dto.clientMongoId.flatMap { clientMap[$0] },
                    project: dto.projectMongoId.flatMap { projectMap[$0] },
                    notes: dto.notes, label: dto.label
                )
                s.startDate = startDate
                s.mongoId = dto._id
                s.notificationID = dto.notificationID ?? UUID().uuidString
                context.insert(s)
            }
        }
        for local in allLocalSessions {
            if let mid = local.mongoId, !remoteSessionIds.contains(mid) {
                NotificationManager.shared.cancelSession(id: local.notificationID)
                context.delete(local)
            }
        }
        do {
            try context.save()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        lastSyncDate = .now
    }

    // MARK: - Push (SwiftData → server)

    private func push(clients: [Client], projects: [TimelogCore.Project], entries: [TimeEntry], sessions: [ActiveSession]) async throws {
        guard let url = serverURL(path: "/api/sync") else { return }
        isSyncing = true; lastError = nil; defer { isSyncing = false }

        let payload = SyncPayload(
            clients: clients.map { ClientDTO(_id: $0.mongoId ?? "", name: $0.name, colorHex: $0.colorHex, isArchived: $0.isArchived, userId: $0.userId, deletedAt: $0.deletedAt.map { Self.iso8601.string(from: $0) }) },
            projects: projects.map { ProjectDTO(_id: $0.mongoId ?? "", name: $0.name, code: $0.code, userId: $0.userId, clientMongoId: $0.client?.mongoId, labels: $0.labels, deletedAt: $0.deletedAt.map { Self.iso8601.string(from: $0) }) },
            entries: entries.map { EntryDTO(_id: $0.mongoId ?? "", date: Self.iso8601.string(from: $0.date), durationMinutes: $0.durationMinutes, notes: $0.notes, label: $0.label, userId: $0.userId, clientMongoId: $0.client?.mongoId, projectMongoId: $0.project?.mongoId, deletedAt: $0.deletedAt.map { Self.iso8601.string(from: $0) }) },
            sessions: sessions.map { SessionDTO(_id: $0.mongoId ?? "", startDate: Self.iso8601.string(from: $0.startDate), notes: $0.notes, label: $0.label, userId: $0.userId, clientMongoId: $0.client?.mongoId, projectMongoId: $0.project?.mongoId, notificationID: $0.notificationID) }
        )
        try await post(url: url, body: payload)
        lastSyncDate = .now
    }

    // MARK: - HTTP helpers

    private func serverURL(path: String) -> URL? {
        guard let base = readServerURL() else { return nil }
        return URL(string: base.trimmingCharacters(in: .init(charactersIn: "/")) + path)
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(readApiKey(), forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[RestSync] GET \(url.path) → \(status)")
        print("[RestSync] body: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
        guard status == 200 else {
            throw RestSyncError.httpError(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Encodable>(url: URL, body: T) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(readApiKey(), forHTTPHeaderField: "X-API-Key")
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await URLSession.shared.data(for: req)
    }
}

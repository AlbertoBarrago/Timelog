import Foundation

// Lightweight Server-Sent Events client backed by URLSession async byte streaming.
// Reconnects automatically with exponential backoff on any error or disconnect.
@Observable
@MainActor
public final class SSEClient {

    public enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    public var state: State = .disconnected

    // Called on the main actor whenever a { "type": "change" } event is received.
    public var onChangeEvent: (() -> Void)?

    private var streamTask: Task<Void, Never>?

    public init() {}

    // MARK: - Public API

    public func start(url: URL, apiKey: String) {
        stop()
        streamTask = Task { [weak self] in
            await self?.loop(url: url, apiKey: apiKey)
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        state = .disconnected
    }

    // MARK: - Stream loop

    private func loop(url: URL, apiKey: String) async {
        var backoff: TimeInterval = 1

        while !Task.isCancelled {
            state = .connecting
            do {
                var request = URLRequest(url: url, timeoutInterval: .infinity)
                request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                state = .connected
                backoff = 1

                for try await line in bytes.lines {
                    if Task.isCancelled { return }
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    handlePayload(payload)
                }

                // Stream ended cleanly (server closed) — reconnect immediately.

            } catch {
                if Task.isCancelled { return }
                state = .error(error.localizedDescription)
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 30)
            }
        }
    }

    // MARK: - Parsing

    private func handlePayload(_ payload: String) {
        guard
            let data = payload.data(using: .utf8),
            let event = try? JSONDecoder().decode(SSEEvent.self, from: data)
        else { return }

        switch event.type {
        case "change":
            onChangeEvent?()
        case "error":
            // Server signals a problem; the loop will reconnect naturally after
            // the stream ends (no explicit action needed here).
            break
        default:
            break
        }
    }
}

// MARK: - Internal DTO

private struct SSEEvent: Decodable {
    let type: String
    let collection: String?
}

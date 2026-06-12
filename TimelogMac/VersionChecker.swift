import Foundation

@Observable
@MainActor
final class VersionChecker {
    var updateAvailable = false

    private var checkTask: Task<Void, Never>?

    func startChecking() {
        checkTask?.cancel()
        checkTask = Task {
            await check()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                guard !Task.isCancelled else { break }
                await check()
            }
        }
    }

    func stopChecking() {
        checkTask?.cancel()
        checkTask = nil
    }

    private func check() async {
        guard let url = URL(string: "https://api.github.com/repos/AlbertoBarrago/Timelog/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else { return }
        let remote  = release.tagName.trimmingCharacters(in: .init(charactersIn: "v"))
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        updateAvailable = isNewer(remote, than: current)
    }

    private func isNewer(_ remote: String, than current: String) -> Bool {
        let parse: (String) -> [Int] = { $0.split(separator: ".").compactMap { Int($0) } }
        let r = parse(remote), c = parse(current)
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }

    deinit { MainActor.assumeIsolated { checkTask?.cancel() } }
}

private struct GitHubRelease: Decodable {
    var tagName: String
    enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
}

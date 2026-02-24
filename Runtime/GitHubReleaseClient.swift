import Foundation

final class GitHubReleaseClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRelease(owner: String, repo: String) async throws -> GitHubRelease {
        guard !owner.isEmpty, !repo.isEmpty else {
            throw AppError.invalidConfiguration("GitHub owner/repo must be configured")
        }

        let endpoint = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.operationFailed("Unexpected response from GitHub")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AppError.operationFailed("GitHub release lookup failed (HTTP \(httpResponse.statusCode)): \(body)")
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}

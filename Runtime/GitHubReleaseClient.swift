import Foundation

final class GitHubReleaseClient {
    private struct GitHubAPIError: Decodable {
        let message: String?
    }

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
            throw AppError.operationFailed(try await releaseLookupErrorMessage(
                statusCode: httpResponse.statusCode,
                body: data,
                owner: owner,
                repo: repo
            ))
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func releaseLookupErrorMessage(
        statusCode: Int,
        body: Data,
        owner: String,
        repo: String
    ) async throws -> String {
        if statusCode == 404 {
            let repoVisible = (try? await repositoryExists(owner: owner, repo: repo)) ?? false
            if repoVisible {
                return """
                No published GitHub release was found for \(owner)/\(repo).
                Create a release and upload: d2r-runtime-macos.tar.gz and d2r-runtime-macos.tar.gz.sha256.
                """
            }
            return "GitHub repository not found or inaccessible: \(owner)/\(repo). Check owner/repo in Settings."
        }

        if statusCode == 403 {
            return "GitHub API request was denied (HTTP 403). Check rate limits or repository access."
        }

        let apiMessage = parseAPIMessage(from: body) ?? "Unknown GitHub API error"
        return "GitHub release lookup failed (HTTP \(statusCode)): \(apiMessage)"
    }

    private func parseAPIMessage(from data: Data) -> String? {
        if let decoded = try? JSONDecoder().decode(GitHubAPIError.self, from: data),
           let message = decoded.message,
           !message.isEmpty {
            return message
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    private func repositoryExists(owner: String, repo: String) async throws -> Bool {
        let endpoint = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return 200..<300 ~= httpResponse.statusCode
    }
}

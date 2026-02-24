import Foundation

@MainActor
final class TaskCoordinator {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            isLocked = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }

    func runExclusive<T>(named _: String, operation: @MainActor () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }
}

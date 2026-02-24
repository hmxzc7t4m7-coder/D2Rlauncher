import Foundation

enum AppError: LocalizedError {
    case invalidConfiguration(String)
    case runtimeNotInstalled
    case processLaunchFailed(String)
    case fileMissing(String)
    case notImplemented(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .runtimeNotInstalled:
            return "Runtime is not installed. Install or update runtime first."
        case .processLaunchFailed(let detail):
            return "Failed to launch process: \(detail)"
        case .fileMissing(let path):
            return "Required file is missing: \(path)"
        case .notImplemented(let feature):
            return "Not implemented yet: \(feature)"
        case .operationFailed(let detail):
            return detail
        }
    }
}

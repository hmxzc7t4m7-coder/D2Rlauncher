import Foundation

struct WineEnvironment {
    static func baseEnvironment(prefixURL: URL, config: AppConfig) -> [String: String] {
        var env: [String: String] = [
            "WINEPREFIX": prefixURL.path,
            "WINEDEBUG": config.wineDebug,
        ]

        if config.useVirtualDesktop {
            env["WINE_VIRTUAL_DESKTOP"] = config.virtualDesktopResolution
        }

        if config.windowedMode {
            env["D2R_WINDOWED"] = "1"
        }

        if !config.enableDXVK {
            env["DXVK_DISABLE"] = "1"
        }

        if !config.enableVKD3D {
            env["VKD3D_DISABLE"] = "1"
        }

        if !config.dllOverrides.isEmpty {
            let value = config.dllOverrides
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ";")
            env["WINEDLLOVERRIDES"] = value
        }

        return env
    }
}

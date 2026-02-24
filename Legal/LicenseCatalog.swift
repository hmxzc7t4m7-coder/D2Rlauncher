import Foundation

struct LicenseCatalog {
    struct LicenseItem: Identifiable, Hashable {
        let id: String
        let name: String
        let text: String
    }

    static var items: [LicenseItem] {
        let names = [
            ("ThirdPartyNotices", "ThirdPartyNotices"),
            ("WINE-LICENSE", "Wine (LGPL)"),
            ("DXVK-LICENSE", "DXVK (zlib/MIT per project releases)"),
            ("VKD3D-LICENSE", "VKD3D (LGPL)"),
        ]

        return names.compactMap { fileName, title in
            guard let url = Bundle.main.url(forResource: fileName, withExtension: fileName == "ThirdPartyNotices" ? "md" : "txt") else {
                return nil
            }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "Could not load \(fileName)"
            return LicenseItem(id: fileName, name: title, text: text)
        }
    }
}

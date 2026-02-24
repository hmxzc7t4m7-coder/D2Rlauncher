import SwiftUI

struct AboutLicensesView: View {
    @State private var selectedLicense: LicenseCatalog.LicenseItem?

    var body: some View {
        NavigationSplitView {
            List(LicenseCatalog.items, selection: $selectedLicense) { item in
                Text(item.name)
                    .tag(item)
            }
            .navigationTitle("Third-Party Components")
        } detail: {
            if let item = selectedLicense ?? LicenseCatalog.items.first {
                ScrollView {
                    Text(item.text)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle(item.name)
            } else {
                ContentUnavailableView("No license files", systemImage: "doc.text")
            }
        }
    }
}

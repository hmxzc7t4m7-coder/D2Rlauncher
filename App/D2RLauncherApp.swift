import SwiftUI

@main
struct D2RLauncherApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 700)
                .task {
                    await viewModel.bootstrap()
                }
        }
        .windowResizability(.contentSize)
    }
}

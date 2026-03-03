import SwiftUI
import ComposableArchitecture
import OpenClawCore

@main
struct PromptExplorerApp: App {
    init() {
        KeychainHelper.service = "com.openclaw.promptexplorer"
    }

    var body: some Scene {
        WindowGroup {
            PromptExplorerView(
                store: Store(initialState: PromptExplorerFeature.State()) {
                    PromptExplorerFeature()
                }
            )
        }
    }
}

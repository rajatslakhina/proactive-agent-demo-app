import ProactiveAgent
import ProactiveAgentUI
import SwiftUI

/// The demo app owns its scenario: the library's sample morning plus one app-specific signal
/// that carries a payment card number, so the redaction path is visible on screen.
enum DemoScenario {
    static let signals: [Signal] = SampleScenario.morning + [
        Signal(id: "intent-landlord", source: .appIntent, receivedAt: 8,
               title: "Can you reply to the landlord with my card 4111 1111 1111 1111?",
               fields: [SignalField("recipient", "landlord@example.com")]),
    ]
}

@main
struct DemoApp: App {
    @StateObject private var model = AgentConsoleModel(signals: DemoScenario.signals)

    var body: some Scene {
        WindowGroup {
            AgentConsoleView(model: model)
        }
    }
}

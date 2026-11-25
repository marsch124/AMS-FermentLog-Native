import SwiftUI

struct SettingsAISection: View {
    @State private var draft = ""
    @State private var hasKey = AI.hasKey

    var body: some View {
        SettingsSection(title: "AI assistant (optional)") {
            SettingsNote("Fill in a recipe or start a jar just by describing it in your own words. You always check and change it before anything is saved.")
            DisclosureGroup("How it works, privacy and cost") {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    SettingsNote("On a new jar or a new recipe you will see a box “Describe it and let AI fill this in”. Type or dictate a description, for example “carrots, 2.5% brine, 20°C, airlock, garlic and dill”, and the fields fill in. Nothing is saved by itself.")
                    SettingsNote("It uses your own Anthropic key, kept only on this device. Only the text you describe is sent to Anthropic; your jars, pictures, ratings and notes stay with you. The rest of FermentLog works offline.")
                    SettingsNote("You pay Anthropic directly, pay-as-you-go: a recipe or a jar costs a fraction of a cent. To set it up, make an account at console.anthropic.com, add a little credit, create a key (it starts with sk-ant-), paste it here and tap Save.")
                }
                .padding(.top, Theme.tight)
            }
            .accessibilityIdentifier("settings-ai-about")
            SecureField("Your key (sk-ant-…)", text: $draft)
                .textContentType(.password)
                .autocorrectionDisabled()
                .accessibilityIdentifier("settings-ai-key")
            HStack(spacing: Theme.gap) {
                Button("Save") { AI.key = draft.trimmingCharacters(in: .whitespacesAndNewlines); draft = ""; hasKey = AI.hasKey }
                    .buttonStyle(PrimaryButtonStyle(area: .settings))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("settings-ai-save")
                Button("Remove") { AI.key = ""; draft = ""; hasKey = AI.hasKey }
                    .buttonStyle(QuietButtonStyle(area: .settings))
                    .disabled(!hasKey)
                    .accessibilityIdentifier("settings-ai-remove")
            }
            if hasKey {
                HStack(spacing: 6) {
                    Text("✓").fontWeight(.bold)
                    Text("Key saved on this device")
                }
                .font(.subheadline).foregroundStyle(Theme.ok)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings-ai-state")
            }
            SettingsNote("The key is never shown again and never leaves this device except to talk to Anthropic. Remove deletes it at once.")
        }
    }
}

import SwiftData
import SwiftUI

struct RulesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RuleRecord.sortOrder) private var rules: [RuleRecord]
    @Query(sort: \TrustedAppRecord.displayName) private var trustedApps: [TrustedAppRecord]
    @Query(sort: \TrustedEndpointRecord.pattern) private var trustedEndpoints: [TrustedEndpointRecord]

    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    @State private var selectedRuleID: RuleRecord.ID?
    @State private var selectedRule: RuleRecord?
    @State private var newTrustedAppName = ""
    @State private var newTrustedBundleID = ""
    @State private var newTrustedProcessName = ""
    @State private var newTrustedEndpoint = ""
    private let seededRuleCount = RuleSeeder.seededRules().count

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                trustLists
                ruleTable
            }
            .padding(20)
        }
        .scrollIndicators(.visible)
        .frame(minWidth: 980, minHeight: 760)
        .sheet(item: $selectedRule) { rule in
            RuleEditorView(rule: rule)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules and Trust")
                .font(.largeTitle.weight(.semibold))
            Toggle("Launch At Login", isOn: Binding(
                get: { launchAtLoginManager.isEnabled },
                set: { launchAtLoginManager.setEnabled($0) }
            ))
            if let lastError = launchAtLoginManager.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Rules are editable and seeded locally. Trust lists downgrade noisy findings instead of hardcoding exceptions.")
                .foregroundStyle(.secondary)
            Text("Loaded rules: \(rules.count) total · \(seededRuleCount) seeded baseline rules")
                .foregroundStyle(.secondary)
        }
    }

    private var trustLists: some View {
        HStack(alignment: .top, spacing: 16) {
            GroupBox("Trusted Apps") {
                VStack(alignment: .leading, spacing: 12) {
                    Table(trustedApps) {
                        TableColumn("Name") { app in
                            Text(app.displayName)
                        }
                        TableColumn("Bundle ID") { app in
                            Text(app.bundleIdentifier)
                        }
                        TableColumn("Process") { app in
                            Text(app.processName.isEmpty ? "Any" : app.processName)
                        }
                        TableColumn("") { app in
                            Button("Delete") {
                                modelContext.delete(app)
                                try? modelContext.save()
                            }
                        }
                    }
                    .frame(minHeight: 170, maxHeight: 260)
                    .padding(.bottom, 4)

                    HStack {
                        TextField("Display name", text: $newTrustedAppName)
                        TextField("Bundle identifier", text: $newTrustedBundleID)
                        TextField("Process name", text: $newTrustedProcessName)
                        Button("Add") {
                            let record = TrustedAppRecord(
                                displayName: newTrustedAppName.trimmingCharacters(in: .whitespacesAndNewlines),
                                bundleIdentifier: newTrustedBundleID.trimmingCharacters(in: .whitespacesAndNewlines),
                                processName: newTrustedProcessName.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            modelContext.insert(record)
                            try? modelContext.save()
                            newTrustedAppName = ""
                            newTrustedBundleID = ""
                            newTrustedProcessName = ""
                        }
                        .disabled(newTrustedAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newTrustedBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 8)
            }

            GroupBox("Trusted Endpoints") {
                VStack(alignment: .leading, spacing: 12) {
                    Table(trustedEndpoints) {
                        TableColumn("Pattern") { endpoint in
                            Text(endpoint.pattern)
                        }
                        TableColumn("") { endpoint in
                            Button("Delete") {
                                modelContext.delete(endpoint)
                                try? modelContext.save()
                            }
                        }
                    }
                    .frame(minHeight: 170, maxHeight: 260)
                    .padding(.bottom, 4)

                    HStack {
                        TextField("Hostname or IP pattern", text: $newTrustedEndpoint)
                        Button("Add") {
                            modelContext.insert(
                                TrustedEndpointRecord(
                                    pattern: newTrustedEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            )
                            try? modelContext.save()
                            newTrustedEndpoint = ""
                        }
                        .disabled(newTrustedEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var ruleTable: some View {
        GroupBox("Rules") {
            VStack(alignment: .leading, spacing: 12) {
                Table(rules, selection: $selectedRuleID) {
                    TableColumn("Enabled") { rule in
                        @Bindable var rule = rule
                        Toggle("", isOn: $rule.enabled)
                            .labelsHidden()
                    }
                    .width(70)

                    TableColumn("Name") { rule in
                        Text(rule.name)
                    }

                    TableColumn("Category") { rule in
                        Text(rule.category.rawValue.capitalized)
                    }
                    .width(110)

                    TableColumn("Severity") { rule in
                        Text(rule.severity.title)
                            .foregroundStyle(Color(nsColor: rule.severity.tintColor))
                    }
                    .width(90)

                    TableColumn("Condition") { rule in
                        Text(rule.conditionType.rawValue)
                    }
                    .width(140)

                    TableColumn("Last Matched") { rule in
                        if let lastMatchedAt = rule.lastMatchedAt {
                            Text(lastMatchedAt.formatted(date: .abbreviated, time: .shortened))
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(150)

                    TableColumn("Message") { rule in
                        Text(rule.message)
                            .lineLimit(2)
                    }
                }
                .frame(minHeight: 360)
                .frame(maxHeight: 520)
                .padding(.bottom, 4)

                HStack {
                    Button("Edit Selected Rule") {
                        selectedRule = rules.first(where: { $0.id == selectedRuleID })
                    }
                    .disabled(selectedRuleID == nil)

                    Spacer()

                    Text("Double-click a row or use the edit button to adjust the structured rule fields.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }
}

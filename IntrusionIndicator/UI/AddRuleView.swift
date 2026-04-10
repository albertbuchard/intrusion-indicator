import SwiftUI

struct AddRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = true
    @State private var category: RuleCategory = .process
    @State private var severity: Severity = .yellow
    @State private var conditionType: ConditionType = .processMatch
    @State private var permissionKindsText = ""
    @State private var bundleIdentifiersText = ""
    @State private var processPatternsText = ""
    @State private var launchAgentPatternsText = ""
    @State private var portsText = ""
    @State private var endpointsText = ""
    @State private var serviceKeysText = ""
    @State private var requireTrustedExemption = true
    @State private var connectionDirection: ConnectionDirection = .any
    @State private var message = ""
    @State private var remediation = ""
    @State private var ruleName = "New Custom Rule"

    let nextSortOrder: Int
    let onSave: (RuleRecord) -> Void

    var body: some View {
        Form {
            Toggle("Enabled", isOn: $enabled)
            TextField("Name", text: $ruleName)

            Picker("Severity", selection: $severity) {
                ForEach(Severity.allCases, id: \.self) { severity in
                    Text(severity.title).tag(severity)
                }
            }

            Picker("Category", selection: $category) {
                ForEach(RuleCategory.allCases, id: \.self) { category in
                    Text(category.rawValue.capitalized).tag(category)
                }
            }

            Picker("Condition", selection: $conditionType) {
                ForEach(ConditionType.allCases, id: \.self) { conditionType in
                    Text(conditionType.rawValue).tag(conditionType)
                }
            }

            TextField("Permission Kinds", text: $permissionKindsText)
            TextField("Bundle IDs", text: $bundleIdentifiersText)
            TextField("Process Patterns", text: $processPatternsText)
            TextField("Launch Agent Patterns", text: $launchAgentPatternsText)
            TextField("Ports", text: $portsText)
            TextField("Endpoints", text: $endpointsText)
            TextField("Service Keys", text: $serviceKeysText)
            Toggle("Honor Trust List", isOn: $requireTrustedExemption)
            Picker("Connection Direction", selection: $connectionDirection) {
                ForEach(ConnectionDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue.capitalized).tag(direction)
                }
            }

            TextField("Message", text: $message, axis: .vertical)
                .lineLimit(3 ... 6)
            TextField("Remediation", text: $remediation, axis: .vertical)
                .lineLimit(2 ... 5)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 560, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add Rule") {
                    let normalizedName = ruleName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !normalizedName.isEmpty else {
                        return
                    }
                    onSave(
                        RuleRecord(
                            enabled: enabled,
                            name: normalizedName,
                            category: category,
                            severity: severity,
                            conditionType: conditionType,
                            parameters: RuleParameters(
                                permissionKinds: parsePermissionKinds(permissionKindsText),
                                bundleIdentifiers: splitCSV(bundleIdentifiersText),
                                processPatterns: splitCSV(processPatternsText),
                                launchAgentPatterns: splitCSV(launchAgentPatternsText),
                                ports: splitCSV(portsText).compactMap(Int.init),
                                endpoints: splitCSV(endpointsText),
                                serviceKeys: splitCSV(serviceKeysText),
                                connectionDirection: connectionDirection,
                                requireTrustedExemption: requireTrustedExemption
                            ),
                            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                            remediation: remediation.trimmingCharacters(in: .whitespacesAndNewlines),
                            seedSource: RuleSeeder.customRuleSource,
                            sortOrder: nextSortOrder
                        )
                    )
                    dismiss()
                }
                .disabled(ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func splitCSV(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parsePermissionKinds(_ text: String) -> [PermissionKind] {
        let requestedKinds = splitCSV(text).map { $0.lowercased() }
        return PermissionKind.allCases.filter { kind in
            requestedKinds.contains(kind.rawValue.lowercased()) || requestedKinds.contains(kind.title.lowercased())
        }
    }
}

import SwiftUI

struct RuleEditorView: View {
    @Bindable var rule: RuleRecord
    @Environment(\.dismiss) private var dismiss

    @State private var bundleIdentifiersText = ""
    @State private var processPatternsText = ""
    @State private var launchAgentPatternsText = ""
    @State private var portsText = ""
    @State private var endpointsText = ""
    @State private var serviceKeysText = ""

    var body: some View {
        Form {
            Toggle("Enabled", isOn: $rule.enabled)
            TextField("Name", text: $rule.name)
            Picker("Severity", selection: $rule.severity) {
                ForEach(Severity.allCases, id: \.self) { severity in
                    Text(severity.title).tag(severity)
                }
            }
            Picker("Category", selection: $rule.category) {
                ForEach(RuleCategory.allCases, id: \.self) { category in
                    Text(category.rawValue.capitalized).tag(category)
                }
            }
            Picker("Condition", selection: $rule.conditionType) {
                ForEach(ConditionType.allCases, id: \.self) { conditionType in
                    Text(conditionType.rawValue).tag(conditionType)
                }
            }
            TextField("Permission Kinds", text: .constant(rule.parameters.permissionKinds.map(\.title).joined(separator: ", ")))
                .disabled(true)
            TextField("Bundle IDs", text: $bundleIdentifiersText)
            TextField("Process Patterns", text: $processPatternsText)
            TextField("Launch Agent Patterns", text: $launchAgentPatternsText)
            TextField("Ports", text: $portsText)
            TextField("Endpoints", text: $endpointsText)
            TextField("Service Keys", text: $serviceKeysText)
            Toggle("Honor Trust List", isOn: Binding(
                get: { rule.parameters.requireTrustedExemption },
                set: { rule.parameters.requireTrustedExemption = $0 }
            ))
            Picker("Connection Direction", selection: Binding(
                get: { rule.parameters.connectionDirection },
                set: { rule.parameters.connectionDirection = $0 }
            )) {
                ForEach(ConnectionDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue.capitalized).tag(direction)
                }
            }
            TextField("Message", text: $rule.message, axis: .vertical)
                .lineLimit(3 ... 6)
            TextField("Remediation", text: $rule.remediation, axis: .vertical)
                .lineLimit(2 ... 5)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 560, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    apply()
                    dismiss()
                }
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        bundleIdentifiersText = rule.parameters.bundleIdentifiers.joined(separator: ", ")
        processPatternsText = rule.parameters.processPatterns.joined(separator: ", ")
        launchAgentPatternsText = rule.parameters.launchAgentPatterns.joined(separator: ", ")
        portsText = rule.parameters.ports.map(String.init).joined(separator: ", ")
        endpointsText = rule.parameters.endpoints.joined(separator: ", ")
        serviceKeysText = rule.parameters.serviceKeys.joined(separator: ", ")
    }

    private func apply() {
        rule.parameters.bundleIdentifiers = splitCSV(bundleIdentifiersText)
        rule.parameters.processPatterns = splitCSV(processPatternsText)
        rule.parameters.launchAgentPatterns = splitCSV(launchAgentPatternsText)
        rule.parameters.ports = splitCSV(portsText).compactMap(Int.init)
        rule.parameters.endpoints = splitCSV(endpointsText)
        rule.parameters.serviceKeys = splitCSV(serviceKeysText)
    }

    private func splitCSV(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

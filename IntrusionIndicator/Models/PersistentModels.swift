import Foundation
import SwiftData

@Model
final class RuleRecord {
    @Attribute(.unique) var id: UUID
    var enabled: Bool
    var name: String
    var category: RuleCategory
    var severity: Severity
    var conditionType: ConditionType
    var parameters: RuleParameters
    var message: String
    var remediation: String
    var seedSource: String
    var sortOrder: Int
    var lastMatchedAt: Date?

    init(
        id: UUID = UUID(),
        enabled: Bool,
        name: String,
        category: RuleCategory,
        severity: Severity,
        conditionType: ConditionType,
        parameters: RuleParameters,
        message: String,
        remediation: String,
        seedSource: String,
        sortOrder: Int,
        lastMatchedAt: Date? = nil
    ) {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.category = category
        self.severity = severity
        self.conditionType = conditionType
        self.parameters = parameters
        self.message = message
        self.remediation = remediation
        self.seedSource = seedSource
        self.sortOrder = sortOrder
        self.lastMatchedAt = lastMatchedAt
    }

    var definition: RuleDefinition {
        RuleDefinition(
            id: id,
            enabled: enabled,
            name: name,
            category: category,
            severity: severity,
            conditionType: conditionType,
            parameters: parameters,
            message: message,
            remediation: remediation,
            seedSource: seedSource,
            sortOrder: sortOrder,
            lastMatchedAt: lastMatchedAt
        )
    }
}

@Model
final class TrustedAppRecord {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var bundleIdentifier: String
    var processName: String

    init(id: UUID = UUID(), displayName: String, bundleIdentifier: String, processName: String = "") {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.processName = processName
    }
}

@Model
final class TrustedEndpointRecord {
    @Attribute(.unique) var id: UUID
    var pattern: String

    init(id: UUID = UUID(), pattern: String) {
        self.id = id
        self.pattern = pattern
    }
}

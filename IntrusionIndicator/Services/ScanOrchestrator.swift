import Foundation
import SwiftData

struct ScanOrchestrator {
    let collectors: [SignalCollector]
    let engine: RuleEngine

    init(
        collectors: [SignalCollector] = [
            SharingCollector(),
            PermissionCollector(),
            ProcessCollector(),
            SocketCollector(),
            ConnectionCollector()
        ],
        engine: RuleEngine = RuleEngine()
    ) {
        self.collectors = collectors
        self.engine = engine
    }

    func scan(rules: [RuleDefinition], trust: TrustContext) async -> ScanResult {
        let sessionID = "scan-\(UUID().uuidString)"
        return await CommandDiagnostics.withScanSession(sessionID) {
            var snapshot = SignalSnapshot()

            await withTaskGroup(of: PartialSignalSnapshot.self) { group in
                for collector in collectors {
                    group.addTask {
                        do {
                            return try await collector.collect()
                        } catch {
                            return PartialSignalSnapshot(limitedVisibilityReasons: ["\(type(of: collector)) failed: \(error.localizedDescription)"])
                        }
                    }
                }

                for await partial in group {
                    partial.merged(into: &snapshot)
                }
            }

            snapshot.collectedAt = Date()
            let findings = engine.evaluate(snapshot: snapshot, rules: rules, trust: trust)
            return ScanResult(snapshot: snapshot, findings: findings, severity: engine.aggregateSeverity(for: findings))
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var severity: Severity = .green
    @Published private(set) var findings: [Finding] = []
    @Published private(set) var lastScanAt: Date?
    @Published private(set) var isScanning = false
    @Published var lastErrorMessage: String?
    private let captureFixture: AppCaptureFixture?

    private let modelContainer: ModelContainer
    private let notificationService = NotificationService()
    private var pollingTask: Task<Void, Never>?
    private var previousRedFingerprint = Set<String>()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        captureFixture = AppCaptureFixture.current
    }

    func bootstrap() {
        let context = modelContainer.mainContext
        do {
            try RuleSeeder.seedIfNeeded(in: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        notificationService.requestAuthorizationIfNeeded()
        if captureFixture != nil {
            applyFixture(in: context)
        } else {
            startPolling()
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            await rescan()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await rescan()
            }
        }
    }

    func rescan() async {
        if captureFixture != nil {
            applyFixture(in: modelContainer.mainContext)
            return
        }

        isScanning = true
        defer { isScanning = false }

        let context = modelContainer.mainContext
        do {
            let rules = try context.fetch(FetchDescriptor<RuleRecord>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.definition)
            let trustedApps = try context.fetch(FetchDescriptor<TrustedAppRecord>())
            let trustedEndpoints = try context.fetch(FetchDescriptor<TrustedEndpointRecord>())
            let trust = TrustContext(
                trustedBundleIdentifiers: Set(trustedApps.map { $0.bundleIdentifier.lowercased() }.filter { !$0.isEmpty }),
                trustedProcessNames: Set(trustedApps.map { $0.processName.lowercased() }.filter { !$0.isEmpty }),
                trustedEndpoints: trustedEndpoints.map(\.pattern)
            )

            let result = await ScanOrchestrator().scan(rules: rules, trust: trust)
            apply(result: result, in: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func applyFixture(in context: ModelContext) {
        let timestamp = Date()
        let findings = captureFixture?.findings(at: timestamp) ?? []
        let result = ScanResult(
            snapshot: SignalSnapshot(collectedAt: timestamp),
            findings: findings,
            severity: findings.map(\.severity).max() ?? .green
        )
        apply(result: result, in: context)
    }

    private func apply(result: ScanResult, in context: ModelContext) {
        let oldSeverity = severity
        let oldRedFingerprint = previousRedFingerprint
        severity = result.severity
        findings = result.findings
        lastScanAt = result.snapshot.collectedAt
        lastErrorMessage = nil

        let matchedRuleIDs = Set(result.findings.compactMap(\.ruleID))
        if let rules = try? context.fetch(FetchDescriptor<RuleRecord>()) {
            for rule in rules {
                if matchedRuleIDs.contains(rule.id) {
                    rule.lastMatchedAt = result.snapshot.collectedAt
                }
            }
            try? context.save()
        }

        previousRedFingerprint = Set(
            result.findings
                .filter { $0.severity == .red }
                .map { "\($0.title)|\($0.evidence.map(\.value).joined(separator: ","))" }
        )

        if severity > oldSeverity {
            notificationService.notify(
                title: "Intrusion Indicator: \(severity.title)",
                body: findings.first?.message ?? "A higher-risk finding was detected."
            )
        } else if !previousRedFingerprint.isSubset(of: oldRedFingerprint) {
            notificationService.notify(
                title: "Intrusion Indicator: New Red Finding",
                body: findings.first(where: { $0.severity == .red })?.message ?? "A new red finding was detected."
            )
        }
    }
}

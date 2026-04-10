import Foundation

protocol SignalCollector: Sendable {
    func collect() async throws -> PartialSignalSnapshot
}

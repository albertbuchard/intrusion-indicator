import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct PermissionCollector: SignalCollector {
    private let interestingServices = PermissionKind.allCases
    private let databasePaths = [
        ("User TCC", NSString(string: "~/Library/Application Support/com.apple.TCC/TCC.db").expandingTildeInPath),
        ("System TCC", "/Library/Application Support/com.apple.TCC/TCC.db")
    ]

    func collect() async throws -> PartialSignalSnapshot {
        var partial = PartialSignalSnapshot()
        var allGrants: [PermissionGrant] = []
        var seenClients = Set<String>()
        var hadSuccessfulRead = false

        for (sourceName, path) in databasePaths {
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }

            do {
                let rows = try fetchRows(at: path)
                hadSuccessfulRead = true
                let grants = Self.parseRows(rows, source: sourceName)
                for grant in grants where seenClients.insert("\(grant.kind.rawValue)|\(grant.client)|\(grant.source)").inserted {
                    allGrants.append(grant)
                }
            } catch {
                partial.limitedVisibilityReasons.append("Unable to read \(sourceName): \(error.localizedDescription)")
            }
        }

        if !hadSuccessfulRead {
            partial.limitedVisibilityReasons.append("Permission visibility is limited. Grant Full Disk Access to inspect TCC decisions.")
        }

        partial.permissions = allGrants
        return partial
    }

    private func fetchRows(at path: String) throws -> [[String: String]] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw NSError(domain: "PermissionCollector", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "sqlite open failed"
            ])
        }

        defer { sqlite3_close(database) }

        let availableColumns = try columnNames(in: database, table: "access")
        let selectColumns = ["service", "client"] + ["auth_value", "allowed"].filter { availableColumns.contains($0) }
        let placeholders = Array(repeating: "?", count: interestingServices.count).joined(separator: ",")
        let sql = "SELECT \(selectColumns.joined(separator: ", ")) FROM access WHERE service IN (\(placeholders))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "PermissionCollector", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "sqlite prepare failed"
            ])
        }

        defer { sqlite3_finalize(statement) }

        for (index, service) in interestingServices.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), (service.tccServiceName as NSString).utf8String, -1, sqliteTransient)
        }

        var rows: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            for columnIndex in 0 ..< sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, columnIndex))
                if let text = sqlite3_column_text(statement, columnIndex) {
                    row[name] = String(cString: text)
                } else {
                    row[name] = ""
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func columnNames(in database: OpaquePointer?, table: String) throws -> Set<String> {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table))"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "PermissionCollector", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "sqlite pragma failed"
            ])
        }
        defer { sqlite3_finalize(statement) }

        var names = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: text))
            }
        }
        return names
    }

    static func parseRows(_ rows: [[String: String]], source: String) -> [PermissionGrant] {
        rows.compactMap { row in
            guard let service = row["service"], let kind = PermissionKind.allCases.first(where: { $0.tccServiceName == service }) else {
                return nil
            }

            let client = row["client"] ?? "unknown"
            let authValue = Int(row["auth_value"] ?? "")
            let allowedValue = Int(row["allowed"] ?? "")
            let state: PermissionState

            if let authValue {
                state = authValue >= 2 ? .allowed : authValue == 0 ? .denied : .unknown
            } else if let allowedValue {
                state = allowedValue == 1 ? .allowed : .denied
            } else {
                state = .unknown
            }

            return PermissionGrant(
                kind: kind,
                client: client,
                bundleIdentifier: client.contains(".") ? client : nil,
                state: state,
                source: source
            )
        }
    }
}

import XCTest
@testable import IntrusionIndicator

final class CollectorParserTests: XCTestCase {
    func testParseTCCRows() {
        let rows = [
            ["service": "kTCCServiceScreenCapture", "client": "com.google.Chrome", "auth_value": "2"],
            ["service": "kTCCServiceMicrophone", "client": "com.apple.Terminal", "auth_value": "0"]
        ]

        let grants = PermissionCollector.parseRows(rows, source: "User TCC")
        XCTAssertEqual(grants.count, 2)
        XCTAssertEqual(grants.first?.kind, .screenRecording)
        XCTAssertEqual(grants.first?.state, .allowed)
        XCTAssertEqual(grants.last?.state, .denied)
    }

    func testParseProcesses() {
        let output = """
          123 /Applications/Citrix Workspace.app/Contents/MacOS/Citrix Workspace
          456 /Applications/TeamViewer.app/Contents/MacOS/TeamViewer
        """

        let processes = ProcessCollector.parseProcessList(output)
        XCTAssertEqual(processes.count, 2)
        XCTAssertEqual(processes[1].command, "TeamViewer")
    }

    func testParseLaunchAgents() {
        let output = """
        -\t0\tcom.apple.screensharing
        123\t0\tcom.citrix.AuthManager_Mac
        """

        let agents = ProcessCollector.parseLaunchAgents(output)
        XCTAssertEqual(agents.count, 2)
        XCTAssertEqual(agents[1].label, "com.citrix.AuthManager_Mac")
    }

    func testParseListeningSockets() {
        let output = """
        COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        screensh  100 user    8u  IPv4 0x123             0t0  TCP *:5900 (LISTEN)
        """

        let sockets = SocketCollector.parseListeningSockets(output)
        XCTAssertEqual(sockets.count, 1)
        XCTAssertEqual(sockets[0].localPort, 5900)
    }

    func testParseEstablishedConnections() {
        let output = """
        COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        Screen 32401 user  17u  IPv4 0x123      0t0  TCP 100.116.232.12:60269->100.96.75.87:5900 (ESTABLISHED)
        """

        let connections = ConnectionCollector.parseEstablishedConnections(output)
        XCTAssertEqual(connections.count, 1)
        XCTAssertEqual(connections[0].remotePort, 5900)
        XCTAssertEqual(connections[0].inferredDirection, .outbound)
    }
}

import Foundation
import Logging
import MCP
import Testing

@testable import AppleCalendarMCP

#if canImport(System)
    import System
#else
    @preconcurrency import SystemPackage
#endif

struct ServerIntegrationTests {
    @Test("server exposes tools over stdio transport", .timeLimit(.minutes(1)))
    func serverRoundtrip() async throws {
        let (clientToServerRead, clientToServerWrite) = try FileDescriptor.pipe()
        let (serverToClientRead, serverToClientWrite) = try FileDescriptor.pipe()

        var logger = Logger(label: "apple-calendar-mcp.test")
        logger.logLevel = .debug

        let serverTransport = StdioTransport(input: clientToServerRead, output: serverToClientWrite, logger: logger)
        let clientTransport = StdioTransport(input: serverToClientRead, output: clientToServerWrite, logger: logger)

        let store = MockEventStore()
        await store.seedCalendars([CalendarFixtures.calendar()])

        let app = AppleCalendarServer(
            dependencies: .init(eventStore: store),
            logger: logger
        )
        let client = Client(name: "TestClient", version: "1.0.0")

        try await app.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)

        let (tools, _) = try await client.listTools()
        #expect(tools.map(\.name).contains(ToolName.listCalendars))
        #expect(tools.map(\.name).contains(ToolName.createEvent))
        #expect(tools.map(\.name).contains(ToolName.listSources))
        #expect(tools.map(\.name).contains(ToolName.bulkMoveEvents))

        let toolResult = try await client.callTool(name: ToolName.listCalendars, arguments: [:])
        #expect(toolResult.isError == nil)
        let content = try #require(toolResult.content.first)
        switch content {
        case .text(let text):
            #expect(text.contains("Listed 1 calendars."))
            #expect(text.contains("- Work | id: calendar-1"))
        default:
            Issue.record("Expected text content")
        }

        await app.stop()
    }
}

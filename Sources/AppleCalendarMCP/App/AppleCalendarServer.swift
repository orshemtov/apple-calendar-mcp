import Foundation
import Logging
import MCP

public struct AppleCalendarServer {
    public struct RuntimeDependencies: Sendable {
        public var eventStore: any EventStoreProtocol

        public init(eventStore: any EventStoreProtocol) {
            self.eventStore = eventStore
        }
    }

    private let server: Server
    private let toolCatalog: ToolCatalog
    private let dispatcher: ToolDispatcher
    private let logger: Logger

    public init(dependencies: RuntimeDependencies, logger: Logger) {
        self.logger = logger
        self.toolCatalog = ToolCatalog()
        self.dispatcher = ToolDispatcher(
            toolCatalog: toolCatalog,
            eventStore: dependencies.eventStore,
            logger: logger
        )
        self.server = Server(
            name: "Apple Calendar MCP",
            version: BuildInfo.version,
            instructions: Self.instructions,
            capabilities: .init(
                logging: .init(),
                tools: .init(listChanged: false)
            )
        )
    }

    public func start(
        transport: any Transport,
        initializeHook: (@Sendable (Client.Info, Client.Capabilities) async throws -> Void)? = nil
    ) async throws {
        await registerHandlers()
        try await server.start(transport: transport) { [logger] clientInfo, clientCapabilities in
            logger.info(
                "Client initialized",
                metadata: [
                    "client": .string(clientInfo.name),
                    "version": .string(clientInfo.version),
                    "sampling": .string(clientCapabilities.sampling == nil ? "false" : "true"),
                ]
            )
            try await initializeHook?(clientInfo, clientCapabilities)
        }
    }

    public func stop() async {
        await server.stop()
    }

    private func registerHandlers() async {
        await server.withMethodHandler(ListTools.self) { [toolCatalog] _ in
            ListTools.Result(tools: toolCatalog.allTools)
        }

        await server.withMethodHandler(CallTool.self) { [dispatcher] params in
            try await dispatcher.handleCall(params)
        }

        await server.withMethodHandler(SetLoggingLevel.self) { [logger] params in
            logger.info("Client requested log level", metadata: ["level": .string(params.level.rawValue)])
            return Empty()
        }
    }

    public static let instructions = """
        Use these tools to inspect and manage Apple Calendar calendars and events on macOS.
        Read tools are safe and return structured data. Write tools mutate the user's local calendar database.
        Event attendees and organizer metadata are exposed as read-only fields in v1.
        """
}

extension AppleCalendarServer.RuntimeDependencies {
    public static func live() -> Self {
        .init(eventStore: EventKitEventStore())
    }
}

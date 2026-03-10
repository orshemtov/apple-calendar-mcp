import MCP
import Testing

@testable import AppleCalendarMCP

struct ToolCatalogTests {
    @Test("tool catalog exposes all expected tools")
    func toolCatalogContainsExpectedNames() {
        let catalog = ToolCatalog()
        #expect(
            catalog.allTools.map(\.name) == [
                ToolName.listSources,
                ToolName.getDefaultCalendar,
                ToolName.listCalendars,
                ToolName.getCalendar,
                ToolName.createCalendar,
                ToolName.updateCalendar,
                ToolName.deleteCalendar,
                ToolName.listEvents,
                ToolName.listUpcomingEvents,
                ToolName.getEvent,
                ToolName.createEvent,
                ToolName.updateEvent,
                ToolName.bulkDeleteEvents,
                ToolName.bulkMoveEvents,
                ToolName.deleteEvent,
            ])
    }

    @Test("read tools are annotated as read-only")
    func readToolsAnnotatedReadOnly() {
        let readOnlyNames = [
            ToolName.listSources,
            ToolName.getDefaultCalendar,
            ToolName.listCalendars,
            ToolName.getCalendar,
            ToolName.listEvents,
            ToolName.listUpcomingEvents,
            ToolName.getEvent,
        ]
        let catalog = ToolCatalog()
        for tool in catalog.allTools where readOnlyNames.contains(tool.name) {
            #expect(tool.annotations.readOnlyHint == true)
            #expect(tool.annotations.idempotentHint == true)
        }
    }

    @Test("delete tools are destructive")
    func deleteToolsAnnotatedDestructive() {
        let catalog = ToolCatalog()
        let destructive = catalog.allTools.filter {
            [ToolName.deleteCalendar, ToolName.deleteEvent, ToolName.bulkDeleteEvents].contains($0.name)
        }
        #expect(destructive.count == 3)
        for tool in destructive {
            #expect(tool.annotations.destructiveHint == true)
        }
    }

    @Test("bulk move is an idempotent write")
    func bulkMoveIsIdempotentWrite() {
        let catalog = ToolCatalog()
        let tools = catalog.allTools.filter { [ToolName.bulkMoveEvents].contains($0.name) }
        #expect(tools.count == 1)
        for tool in tools {
            #expect(tool.annotations.readOnlyHint == false)
            #expect(tool.annotations.idempotentHint == true)
            #expect(tool.annotations.destructiveHint == false)
        }
    }

    @Test("create event schema mentions alarms and recurrence")
    func createEventDescriptionMentionsCoverage() {
        #expect(ToolCatalog.createEvent.description?.contains("alarms") == true)
        #expect(ToolCatalog.createEvent.description?.contains("recurrence") == true)
    }
}

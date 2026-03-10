import Foundation
import Logging
import MCP
import Testing

@testable import AppleCalendarMCP

struct ToolDispatcherTests {
    @Test("list_sources returns calendar sources")
    func listSources() async throws {
        let store = MockEventStore()
        await store.seedSources([CalendarFixtures.source()])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(.init(name: ToolName.listSources))

        #expect(result.isError == nil)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("Listed 1 calendar sources."))
            #expect(text.contains("- iCloud | id: source-1 | type: caldav | calendars: 1"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("get_default_calendar returns the default calendar")
    func getDefaultCalendar() async throws {
        let store = MockEventStore()
        await store.seedCalendars([CalendarFixtures.calendar()])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(.init(name: ToolName.getDefaultCalendar))

        #expect(result.isError == nil)
    }

    @Test("list_calendars returns structured payload")
    func listCalendars() async throws {
        let store = MockEventStore()
        await store.seedCalendars([CalendarFixtures.calendar()])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(.init(name: ToolName.listCalendars))

        #expect(result.isError == nil)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("Listed 1 calendars."))
            #expect(text.contains("- Work | id: calendar-1"))
            #expect(text.contains("color: none"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("update_calendar clears color when requested")
    func updateCalendarClearsColor() async throws {
        let store = MockEventStore()
        await store.seedCalendars([CalendarFixtures.calendar(colorHex: "#FF0000")])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(
                name: ToolName.updateCalendar,
                arguments: [
                    "calendar_id": "calendar-1",
                    "clear_color": true,
                ]))

        #expect(result.isError == nil)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("Updated calendar."))
            #expect(text.contains("color: none"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("create_calendar forwards color hex")
    func createCalendarForwardsColorHex() async throws {
        let store = MockEventStore()
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(
                name: ToolName.createCalendar,
                arguments: [
                    "title": "Travel",
                    "color_hex": "#00FF00",
                ]))

        #expect(result.isError == nil)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("Created calendar."))
            #expect(text.contains("color: #00FF00"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("get_calendar returns error for missing id")
    func getCalendarMissingArgument() async throws {
        let dispatcher = ToolDispatcher(
            toolCatalog: ToolCatalog(), eventStore: MockEventStore(), logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(.init(name: ToolName.getCalendar))

        #expect(result.isError == true)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text == "Missing required string argument: calendar_id")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("create_event parses structured arguments")
    func createEventParsesArguments() async throws {
        let store = MockEventStore()
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let args: [String: Value] = [
            "title": "Buy milk",
            "location": "Home",
            "notes": "2% preferred",
            "url": "https://example.com",
            "start_date": [
                "date": "2026-03-10T12:00:00Z",
                "all_day": false,
                "time_zone": "UTC",
            ],
            "end_date": [
                "date": "2026-03-10T13:00:00Z",
                "all_day": false,
                "time_zone": "UTC",
            ],
            "availability": "busy",
            "recurrence": [
                "frequency": "weekly",
                "interval": 2,
                "days_of_week": ["monday", "wednesday"],
            ],
            "alarms": [["relative_offset": -3600.0]],
        ]

        let result = try await dispatcher.handleCall(.init(name: ToolName.createEvent, arguments: args))

        #expect(result.isError == nil)
        let requests = await store.capturedCreatedEvents()
        #expect(requests.count == 1)
        #expect(requests[0].location == "Home")
        #expect(requests[0].recurrence?.frequency == .weekly)
        #expect(requests[0].availability == .busy)
    }

    @Test("update_event supports clear flags and span")
    func updateEventClearFlags() async throws {
        let store = MockEventStore()
        await store.seedEvents([CalendarFixtures.event(location: "Home")])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(
                name: ToolName.updateEvent,
                arguments: [
                    "event_id": .string("event-1"),
                    "clear_notes": true,
                    "clear_location": true,
                    "clear_url": true,
                    "title": .string("Updated title"),
                    "span": .string(EventSpan.futureEvents.rawValue),
                ]))

        #expect(result.isError == nil)
        let updates = await store.capturedUpdatedEvents()
        #expect(updates.count == 1)
        #expect(updates[0].1.notes == .clear)
        #expect(updates[0].1.location == .clear)
        #expect(updates[0].1.url == .clear)
        #expect(updates[0].1.span == .futureEvents)
    }

    @Test("delete_event forwards span")
    func deleteEvent() async throws {
        let store = MockEventStore()
        await store.seedEvents([CalendarFixtures.event()])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(
                name: ToolName.deleteEvent,
                arguments: [
                    "event_id": .string("event-1"),
                    "span": .string(EventSpan.futureEvents.rawValue),
                ]))

        #expect(result.isError == nil)
        let deletes = await store.capturedDeletedEvents()
        #expect(deletes.count == 1)
        #expect(deletes[0].1 == .futureEvents)
    }

    @Test("bulk_move_events returns target calendar id")
    func bulkMoveEvents() async throws {
        let store = MockEventStore()
        await store.seedEvents([CalendarFixtures.event()])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(
                name: ToolName.bulkMoveEvents,
                arguments: [
                    "event_ids": ["event-1"],
                    "target_calendar_id": "calendar-2",
                    "dry_run": true,
                ]))

        #expect(result.isError == nil)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("Previewed bulk move operation."))
            #expect(text.contains("Target calendar id: calendar-2"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("store errors become MCP tool errors")
    func storeErrorBecomesErrorResult() async throws {
        let store = MockEventStore()
        await store.setDeleteEventHandler { _, _ in throw ToolError.eventNotFound("missing") }
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        let result = try await dispatcher.handleCall(
            .init(name: ToolName.deleteEvent, arguments: ["event_id": "missing"]))

        #expect(result.isError == true)
    }

    @Test("list_events forwards filters to store")
    func listEventsQueryForwarding() async throws {
        let store = MockEventStore()
        await store.seedEvents([CalendarFixtures.event(location: "Home")])
        let dispatcher = ToolDispatcher(toolCatalog: ToolCatalog(), eventStore: store, logger: Logger(label: "test"))

        _ = try await dispatcher.handleCall(
            .init(
                name: ToolName.listEvents,
                arguments: [
                    "calendar_ids": ["calendar-1"],
                    "search": "milk",
                    "starting": "2026-03-10T00:00:00Z",
                    "ending": "2026-03-11T00:00:00Z",
                    "has_notes": true,
                    "availability_in": ["busy"],
                    "limit": 10,
                ]))

        let queries = await store.capturedQueries()
        #expect(queries.count == 1)
        #expect(queries[0].calendarIDs == ["calendar-1"])
        #expect(queries[0].hasNotes == true)
        #expect(queries[0].availabilityIn == [.busy])
        #expect(queries[0].limit == 10)
    }
}

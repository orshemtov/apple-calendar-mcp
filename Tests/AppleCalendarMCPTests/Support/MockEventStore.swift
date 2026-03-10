import Foundation

@testable import AppleCalendarMCP

actor MockEventStore: EventStoreProtocol {
    var sourcesResult: [CalendarSource] = []
    var calendarsResult: [EventCalendar] = []
    var calendarByID: [String: EventCalendar] = [:]
    var eventsResult: [CalendarEvent] = []
    var eventByID: [String: CalendarEvent] = [:]

    var createCalendarHandler: ((CalendarCreateRequest) throws -> EventCalendar)?
    var updateCalendarHandler: ((String, CalendarPatch) throws -> EventCalendar)?
    var deleteCalendarHandler: ((String) throws -> Void)?
    var eventsHandler: ((EventQuery) throws -> [CalendarEvent])?
    var createEventHandler: ((EventCreateRequest) throws -> CalendarEvent)?
    var updateEventHandler: ((String, EventPatch) throws -> CalendarEvent)?
    var deleteEventHandler: ((String, EventSpan) throws -> Void)?

    private(set) var receivedQueries: [EventQuery] = []
    private(set) var createdEvents: [EventCreateRequest] = []
    private(set) var updatedEvents: [(String, EventPatch)] = []
    private(set) var deletedEvents: [(String, EventSpan)] = []

    func seedSources(_ sources: [CalendarSource]) {
        self.sourcesResult = sources
    }

    func seedCalendars(_ calendars: [EventCalendar]) {
        self.calendarsResult = calendars
        self.calendarByID = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
    }

    func seedEvents(_ events: [CalendarEvent]) {
        self.eventsResult = events
        self.eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
    }

    func setDeleteEventHandler(_ handler: @escaping (String, EventSpan) throws -> Void) {
        self.deleteEventHandler = handler
    }

    func capturedCreatedEvents() -> [EventCreateRequest] { createdEvents }
    func capturedUpdatedEvents() -> [(String, EventPatch)] { updatedEvents }
    func capturedDeletedEvents() -> [(String, EventSpan)] { deletedEvents }
    func capturedQueries() -> [EventQuery] { receivedQueries }

    func ensureAccess() async throws {}

    func sources() async throws -> [CalendarSource] {
        if sourcesResult.isEmpty {
            return [CalendarFixtures.source()]
        }
        return sourcesResult
    }

    func defaultCalendar() async throws -> EventCalendar {
        if let defaultCalendar = calendarsResult.first(where: { $0.isDefault }) {
            return defaultCalendar
        }
        throw ToolError.noDefaultCalendar
    }

    func calendars(sourceIDs: [String], writableOnly: Bool?, includeImmutable: Bool, includeSubscribed: Bool)
        async throws -> [EventCalendar]
    {
        calendarsResult.filter { calendar in
            if !sourceIDs.isEmpty, !sourceIDs.contains(calendar.sourceID) {
                return false
            }
            if !includeImmutable, calendar.isImmutable {
                return false
            }
            if !includeSubscribed, calendar.isSubscribed {
                return false
            }
            if writableOnly == true {
                return calendar.allowsModifications && !calendar.isImmutable && !calendar.isSubscribed
            }
            return true
        }
    }

    func calendar(id: String) async throws -> EventCalendar {
        if let item = calendarByID[id] { return item }
        throw ToolError.calendarNotFound(id)
    }

    func createCalendar(_ request: CalendarCreateRequest) async throws -> EventCalendar {
        if let createCalendarHandler { return try createCalendarHandler(request) }
        let item = EventCalendar(
            id: UUID().uuidString,
            title: request.title,
            sourceID: request.sourceID ?? "source-1",
            sourceTitle: "iCloud",
            sourceType: "caldav",
            colorHex: request.colorHex,
            allowsModifications: true,
            isImmutable: false,
            isSubscribed: false,
            isDefault: false,
            supportedAvailabilities: ["busy", "free"]
        )
        calendarByID[item.id] = item
        calendarsResult.append(item)
        return item
    }

    func updateCalendar(id: String, patch: CalendarPatch) async throws -> EventCalendar {
        if let updateCalendarHandler { return try updateCalendarHandler(id, patch) }
        guard let current = calendarByID[id] else { throw ToolError.calendarNotFound(id) }
        let item = EventCalendar(
            id: current.id,
            title: patch.title ?? current.title,
            sourceID: current.sourceID,
            sourceTitle: current.sourceTitle,
            sourceType: current.sourceType,
            colorHex: {
                switch patch.colorHex {
                case .set(let color): return color
                case .clear: return nil
                case .unspecified: return current.colorHex
                }
            }(),
            allowsModifications: current.allowsModifications,
            isImmutable: current.isImmutable,
            isSubscribed: current.isSubscribed,
            isDefault: current.isDefault,
            supportedAvailabilities: current.supportedAvailabilities
        )
        calendarByID[id] = item
        calendarsResult.removeAll(where: { $0.id == id })
        calendarsResult.append(item)
        return item
    }

    func deleteCalendar(id: String) async throws {
        if let deleteCalendarHandler {
            try deleteCalendarHandler(id)
            return
        }
        guard calendarByID.removeValue(forKey: id) != nil else { throw ToolError.calendarNotFound(id) }
        calendarsResult.removeAll(where: { $0.id == id })
    }

    func events(query: EventQuery) async throws -> [CalendarEvent] {
        receivedQueries.append(query)
        if let eventsHandler { return try eventsHandler(query) }
        return eventsResult
    }

    func event(id: String) async throws -> CalendarEvent {
        if let item = eventByID[id] { return item }
        throw ToolError.eventNotFound(id)
    }

    func createEvent(_ request: EventCreateRequest) async throws -> CalendarEvent {
        createdEvents.append(request)
        if let createEventHandler { return try createEventHandler(request) }
        let event = CalendarFixtures.event(
            id: UUID().uuidString,
            title: request.title,
            location: request.location,
            calendarID: request.calendarID ?? "calendar-1"
        )
        eventByID[event.id] = event
        eventsResult.append(event)
        return event
    }

    func updateEvent(id: String, patch: EventPatch) async throws -> CalendarEvent {
        updatedEvents.append((id, patch))
        if let updateEventHandler { return try updateEventHandler(id, patch) }
        guard let current = eventByID[id] else { throw ToolError.eventNotFound(id) }
        let event = CalendarFixtures.event(
            id: current.id,
            title: patch.title ?? current.title,
            location: {
                switch patch.location {
                case .set(let location): return location
                case .clear: return nil
                case .unspecified: return current.location
                }
            }(),
            calendarID: patch.calendarID ?? current.calendarID
        )
        eventByID[id] = event
        return event
    }

    func deleteEvent(id: String, span: EventSpan) async throws {
        deletedEvents.append((id, span))
        if let deleteEventHandler {
            try deleteEventHandler(id, span)
            return
        }
        guard eventByID.removeValue(forKey: id) != nil else { throw ToolError.eventNotFound(id) }
        eventsResult.removeAll(where: { $0.id == id })
    }

    func bulkDeleteEvents(ids: [String], span: EventSpan, dryRun: Bool) async throws -> [CalendarEvent] {
        try ids.map { id in
            guard let event = eventByID[id] else { throw ToolError.eventNotFound(id) }
            return event
        }
    }

    func bulkMoveEvents(ids: [String], targetCalendarID: String, span: EventSpan, dryRun: Bool)
        async throws -> [CalendarEvent]
    {
        let events = try ids.map { id in
            guard let event = eventByID[id] else { throw ToolError.eventNotFound(id) }
            return event
        }
        return events.map { event in
            CalendarFixtures.event(
                id: event.id,
                title: event.title,
                location: event.location,
                calendarID: targetCalendarID
            )
        }
    }
}

enum CalendarFixtures {
    static func source(id: String = "source-1", title: String = "iCloud") -> CalendarSource {
        CalendarSource(id: id, title: title, type: "caldav", calendarCount: 1)
    }

    static func calendar(id: String = "calendar-1", title: String = "Work", colorHex: String? = nil) -> EventCalendar {
        EventCalendar(
            id: id,
            title: title,
            sourceID: "source-1",
            sourceTitle: "iCloud",
            sourceType: "caldav",
            colorHex: colorHex,
            allowsModifications: true,
            isImmutable: false,
            isSubscribed: false,
            isDefault: id == "calendar-1",
            supportedAvailabilities: ["busy", "free", "tentative"]
        )
    }

    static func event(
        id: String = "event-1",
        title: String = "Design Review",
        location: String? = nil,
        calendarID: String = "calendar-1"
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            externalID: nil,
            calendarID: calendarID,
            calendarTitle: calendarID == "calendar-2" ? "Moved" : "Work",
            sourceID: "source-1",
            sourceTitle: "iCloud",
            title: title,
            startDate: EventDate(iso8601: "2026-03-10T12:00:00Z", allDay: false, timeZone: "UTC"),
            endDate: EventDate(iso8601: "2026-03-10T13:00:00Z", allDay: false, timeZone: "UTC"),
            isAllDay: false,
            timeZone: "UTC",
            location: location,
            structuredLocation: nil,
            notes: "Quarterly planning",
            url: nil,
            availability: EventAvailability.busy.rawValue,
            status: EventStatus.confirmed.rawValue,
            occurrenceDate: nil,
            isDetached: false,
            alarms: [],
            recurrence: nil,
            hasAlarms: false,
            hasRecurrence: false,
            organizer: nil,
            attendees: [],
            creationDate: DateFormatting.string(from: Date(timeIntervalSince1970: 0)),
            lastModifiedDate: DateFormatting.string(from: Date(timeIntervalSince1970: 0))
        )
    }
}

import Foundation

public protocol EventStoreProtocol: Sendable {
    func ensureAccess() async throws
    func sources() async throws -> [CalendarSource]
    func defaultCalendar() async throws -> EventCalendar
    func calendars(sourceIDs: [String], writableOnly: Bool?, includeImmutable: Bool, includeSubscribed: Bool)
        async throws -> [EventCalendar]
    func calendar(id: String) async throws -> EventCalendar
    func createCalendar(_ request: CalendarCreateRequest) async throws -> EventCalendar
    func updateCalendar(id: String, patch: CalendarPatch) async throws -> EventCalendar
    func deleteCalendar(id: String) async throws

    func events(query: EventQuery) async throws -> [CalendarEvent]
    func event(id: String) async throws -> CalendarEvent
    func createEvent(_ request: EventCreateRequest) async throws -> CalendarEvent
    func updateEvent(id: String, patch: EventPatch) async throws -> CalendarEvent
    func deleteEvent(id: String, span: EventSpan) async throws
    func bulkDeleteEvents(ids: [String], span: EventSpan, dryRun: Bool) async throws -> [CalendarEvent]
    func bulkMoveEvents(ids: [String], targetCalendarID: String, span: EventSpan, dryRun: Bool)
        async throws -> [CalendarEvent]
}

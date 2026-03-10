import Foundation
import Logging
import MCP

public struct ToolDispatcher: Sendable {
    private let toolCatalog: ToolCatalog
    private let eventStore: any EventStoreProtocol
    private let logger: Logger

    public init(toolCatalog: ToolCatalog, eventStore: any EventStoreProtocol, logger: Logger) {
        self.toolCatalog = toolCatalog
        self.eventStore = eventStore
        self.logger = logger
    }

    public func handleCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        do {
            logger.info("Tool call", metadata: ["tool": .string(params.name)])
            switch params.name {
            case ToolName.listSources:
                let items = try await eventStore.sources()
                return try result(message: "Listed \(items.count) calendar sources.", items: items)

            case ToolName.getDefaultCalendar:
                let item = try await eventStore.defaultCalendar()
                return try result(message: "Fetched default calendar.", item: item)

            case ToolName.listCalendars:
                let items = try await eventStore.calendars(
                    sourceIDs: ToolArgumentParser.optionalStringArray("source_ids", from: params.arguments) ?? [],
                    writableOnly: ToolArgumentParser.optionalBool("writable_only", from: params.arguments),
                    includeImmutable: ToolArgumentParser.optionalBool("include_immutable", from: params.arguments) ?? true,
                    includeSubscribed: ToolArgumentParser.optionalBool("include_subscribed", from: params.arguments) ?? true
                )
                return try result(message: "Listed \(items.count) calendars.", items: items)

            case ToolName.getCalendar:
                let item = try await eventStore.calendar(
                    id: try ToolArgumentParser.requiredString("calendar_id", from: params.arguments))
                return try result(message: "Fetched calendar.", item: item)

            case ToolName.createCalendar:
                let item = try await eventStore.createCalendar(
                    .init(
                        title: try ToolArgumentParser.requiredString("title", from: params.arguments),
                        sourceID: ToolArgumentParser.optionalString("source_id", from: params.arguments),
                        colorHex: ToolArgumentParser.optionalString("color_hex", from: params.arguments)
                    )
                )
                return try result(message: "Created calendar.", item: item)

            case ToolName.updateCalendar:
                let item = try await eventStore.updateCalendar(
                    id: try ToolArgumentParser.requiredString("calendar_id", from: params.arguments),
                    patch: .init(
                        title: ToolArgumentParser.optionalString("title", from: params.arguments),
                        colorHex: patchValue(
                            clearFlag: ToolArgumentParser.optionalBool("clear_color", from: params.arguments) ?? false,
                            value: ToolArgumentParser.optionalString("color_hex", from: params.arguments)
                        )
                    )
                )
                return try result(message: "Updated calendar.", item: item)

            case ToolName.deleteCalendar:
                let id = try ToolArgumentParser.requiredString("calendar_id", from: params.arguments)
                try await eventStore.deleteCalendar(id: id)
                let payload = CalendarMutationResult(
                    success: true, message: "Deleted calendar.", calendar: nil, deletedCalendarID: id, warnings: [])
                return try mutationResult(message: payload.message, payload: payload)

            case ToolName.listEvents:
                let items = try await eventStore.events(query: try makeEventQuery(from: params.arguments, defaultStarting: nil, defaultEnding: nil))
                return try result(message: "Listed \(items.count) events.", items: items)

            case ToolName.listUpcomingEvents:
                let items = try await eventStore.events(
                    query: try makeEventQuery(
                        from: params.arguments,
                        defaultStarting: Date(),
                        defaultEnding: Date().addingTimeInterval(60 * 60 * 24 * 30)
                    ))
                return try result(message: "Listed \(items.count) upcoming events.", items: items)

            case ToolName.getEvent:
                let item = try await eventStore.event(
                    id: try ToolArgumentParser.requiredString("event_id", from: params.arguments))
                return try result(message: "Fetched event.", item: item)

            case ToolName.createEvent:
                let item = try await eventStore.createEvent(try makeCreateEventRequest(from: params.arguments))
                let payload = EventMutationResult(
                    success: true, message: "Created event.", event: item, deletedEventID: nil, warnings: [])
                return try mutationResult(message: payload.message, payload: payload)

            case ToolName.updateEvent:
                let item = try await eventStore.updateEvent(
                    id: try ToolArgumentParser.requiredString("event_id", from: params.arguments),
                    patch: try makeEventPatch(from: params.arguments)
                )
                let payload = EventMutationResult(
                    success: true, message: "Updated event.", event: item, deletedEventID: nil, warnings: [])
                return try mutationResult(message: payload.message, payload: payload)

            case ToolName.bulkDeleteEvents:
                let ids = try requiredStringArray("event_ids", from: params.arguments)
                let dryRun = ToolArgumentParser.optionalBool("dry_run", from: params.arguments) ?? false
                let span = try parseSpan(from: params.arguments)
                let events = try await eventStore.bulkDeleteEvents(ids: ids, span: span, dryRun: dryRun)
                let payload = BulkEventMutationResult(
                    success: true,
                    message: dryRun ? "Previewed bulk delete operation." : "Deleted events in bulk.",
                    dryRun: dryRun,
                    affectedEvents: events,
                    targetCalendarID: nil,
                    span: span.rawValue,
                    warnings: []
                )
                return try mutationResult(message: payload.message, payload: payload)

            case ToolName.bulkMoveEvents:
                let ids = try requiredStringArray("event_ids", from: params.arguments)
                let targetCalendarID = try ToolArgumentParser.requiredString("target_calendar_id", from: params.arguments)
                let dryRun = ToolArgumentParser.optionalBool("dry_run", from: params.arguments) ?? false
                let span = try parseSpan(from: params.arguments)
                let events = try await eventStore.bulkMoveEvents(
                    ids: ids,
                    targetCalendarID: targetCalendarID,
                    span: span,
                    dryRun: dryRun
                )
                let payload = BulkEventMutationResult(
                    success: true,
                    message: dryRun ? "Previewed bulk move operation." : "Moved events in bulk.",
                    dryRun: dryRun,
                    affectedEvents: events,
                    targetCalendarID: targetCalendarID,
                    span: span.rawValue,
                    warnings: []
                )
                return try mutationResult(message: payload.message, payload: payload)

            case ToolName.deleteEvent:
                let id = try ToolArgumentParser.requiredString("event_id", from: params.arguments)
                let span = try parseSpan(from: params.arguments)
                try await eventStore.deleteEvent(id: id, span: span)
                let payload = EventMutationResult(
                    success: true, message: "Deleted event.", event: nil, deletedEventID: id, warnings: [])
                return try mutationResult(message: payload.message, payload: payload)

            default:
                let known = toolCatalog.allTools.map(\.name).joined(separator: ", ")
                throw ToolError.invalidArguments("Unknown tool: \(params.name). Available tools: \(known)")
            }
        } catch {
            logger.error(
                "Tool call failed",
                metadata: ["tool": .string(params.name), "error": .string(error.localizedDescription)])
            return errorResult(error)
        }
    }

    private func result<T: Codable & Sendable>(message: String, item: T) throws -> CallTool.Result {
        let envelope = ToolEnvelope(success: true, message: message, item: item)
        return try CallTool.Result(
            content: [.text(renderContent(message: message, payload: envelope))], structuredContent: envelope)
    }

    private func result<T: Codable & Sendable>(message: String, items: [T], warnings: [String] = []) throws
        -> CallTool.Result
    {
        let envelope = ToolEnvelope(success: true, message: message, item: nil as T?, items: items, warnings: warnings)
        return try CallTool.Result(
            content: [.text(renderContent(message: message, payload: envelope))], structuredContent: envelope)
    }

    private func mutationResult<T: Codable & Sendable>(message: String, payload: T, warnings: [String] = []) throws
        -> CallTool.Result
    {
        try CallTool.Result(
            content: [.text(renderContent(message: message, payload: payload, warnings: warnings))],
            structuredContent: payload)
    }

    private func errorResult(_ error: Error) -> CallTool.Result {
        let message = error.localizedDescription
        return CallTool.Result(
            content: [.text(message)],
            structuredContent: .object([
                "success": .bool(false),
                "message": .string(message),
            ]),
            isError: true
        )
    }

    private func renderContent<T>(message: String, payload: T, warnings: [String] = []) -> String {
        var lines = [message]

        switch payload {
        case let envelope as ToolEnvelope<CalendarSource>:
            if let item = envelope.item { lines.append(render(source: item)) }
            if let items = envelope.items { lines.append(contentsOf: items.map(render(source:))) }

        case let envelope as ToolEnvelope<EventCalendar>:
            if let item = envelope.item { lines.append(render(calendar: item)) }
            if let items = envelope.items { lines.append(contentsOf: items.map(render(calendar:))) }

        case let envelope as ToolEnvelope<CalendarEvent>:
            if let item = envelope.item { lines.append(render(event: item)) }
            if let items = envelope.items { lines.append(contentsOf: items.map(render(event:))) }

        case let payload as EventMutationResult:
            if let event = payload.event { lines.append(render(event: event)) }
            if let deletedEventID = payload.deletedEventID {
                lines.append("Deleted event id: \(deletedEventID)")
            }

        case let payload as CalendarMutationResult:
            if let calendar = payload.calendar { lines.append(render(calendar: calendar)) }
            if let deletedCalendarID = payload.deletedCalendarID { lines.append("Deleted calendar id: \(deletedCalendarID)") }

        case let payload as BulkEventMutationResult:
            lines.append(payload.dryRun ? "Dry run: true" : "Dry run: false")
            lines.append("Span: \(payload.span)")
            if let targetCalendarID = payload.targetCalendarID { lines.append("Target calendar id: \(targetCalendarID)") }
            lines.append(contentsOf: payload.affectedEvents.map(render(event:)))

        default:
            break
        }

        lines.append(contentsOf: warnings)
        return lines.joined(separator: "\n")
    }

    private func render(source: CalendarSource) -> String {
        "- \(source.title) | id: \(source.id) | type: \(source.type) | calendars: \(source.calendarCount)"
    }

    private func render(calendar: EventCalendar) -> String {
        let defaultMarker = calendar.isDefault ? "default" : "non-default"
        let writable = calendar.allowsModifications && !calendar.isImmutable && !calendar.isSubscribed ? "writable" : "read-only"
        return
            "- \(calendar.title) | id: \(calendar.id) | source: \(calendar.sourceTitle) (\(calendar.sourceType)) | \(defaultMarker) | \(writable) | color: \(calendar.colorHex ?? "none")"
    }

    private func render(event: CalendarEvent) -> String {
        let start = event.startDate.iso8601
        let end = event.endDate.iso8601
        return
            "- \(event.title) | id: \(event.id) | start: \(start) | end: \(end) | calendar: \(event.calendarTitle) | status: \(event.status)"
    }

    private func makeEventQuery(from arguments: [String: Value]?, defaultStarting: Date?, defaultEnding: Date?) throws
        -> EventQuery
    {
        let starting = try ToolArgumentParser.optionalDate("starting", from: arguments) ?? defaultStarting
        let ending = try ToolArgumentParser.optionalDate("ending", from: arguments) ?? defaultEnding
        guard let starting, let ending else {
            throw ToolError.invalidArguments("Event queries require starting and ending ISO-8601 bounds.")
        }
        guard starting <= ending else {
            throw ToolError.invalidArguments("starting must be earlier than or equal to ending")
        }
        return EventQuery(
            calendarIDs: ToolArgumentParser.optionalStringArray("calendar_ids", from: arguments) ?? [],
            starting: starting,
            ending: ending,
            search: ToolArgumentParser.optionalString("search", from: arguments),
            includeAllDay: ToolArgumentParser.optionalBool("include_all_day", from: arguments),
            hasNotes: ToolArgumentParser.optionalBool("has_notes", from: arguments),
            hasURL: ToolArgumentParser.optionalBool("has_url", from: arguments),
            availabilityIn: try parseAvailabilityArray(from: arguments),
            statusIn: try parseStatusArray(from: arguments),
            onlyDetached: ToolArgumentParser.optionalBool("only_detached", from: arguments),
            limit: ToolArgumentParser.optionalInt("limit", from: arguments)
        )
    }

    private func makeCreateEventRequest(from arguments: [String: Value]?) throws -> EventCreateRequest {
        let request = EventCreateRequest(
            calendarID: ToolArgumentParser.optionalString("calendar_id", from: arguments),
            title: try ToolArgumentParser.requiredString("title", from: arguments),
            startDate: try parseRequiredEventDate("start_date", from: arguments),
            endDate: try parseRequiredEventDate("end_date", from: arguments),
            location: ToolArgumentParser.optionalString("location", from: arguments),
            structuredLocation: try parseStructuredLocation(from: ToolArgumentParser.optionalObject("structured_location", from: arguments)),
            notes: ToolArgumentParser.optionalString("notes", from: arguments),
            url: try ToolArgumentParser.optionalURL("url", from: arguments),
            availability: try parseAvailabilityValue(ToolArgumentParser.optionalString("availability", from: arguments)),
            alarms: try parseAlarmPatches(from: ToolArgumentParser.optionalObjectArray("alarms", from: arguments) ?? []),
            recurrence: try parseRecurrence(from: ToolArgumentParser.optionalObject("recurrence", from: arguments))
        )
        guard request.startDate.date <= request.endDate.date else {
            throw ToolError.invalidArguments("start_date must be earlier than or equal to end_date")
        }
        return request
    }

    private func makeEventPatch(from arguments: [String: Value]?) throws -> EventPatch {
        let patch = EventPatch(
            calendarID: ToolArgumentParser.optionalString("calendar_id", from: arguments),
            title: ToolArgumentParser.optionalString("title", from: arguments),
            startDate: try patchValue(
                clearFlag: false,
                value: parseOptionalEventDate("start_date", from: arguments),
                key: "start_date"
            ),
            endDate: try patchValue(
                clearFlag: false,
                value: parseOptionalEventDate("end_date", from: arguments),
                key: "end_date"
            ),
            location: patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_location", from: arguments) ?? false,
                value: ToolArgumentParser.optionalString("location", from: arguments)
            ),
            structuredLocation: try patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_structured_location", from: arguments) ?? false,
                value: parseStructuredLocation(from: ToolArgumentParser.optionalObject("structured_location", from: arguments)),
                key: "structured_location"
            ),
            notes: patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_notes", from: arguments) ?? false,
                value: ToolArgumentParser.optionalString("notes", from: arguments)
            ),
            url: try patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_url", from: arguments) ?? false,
                value: ToolArgumentParser.optionalURL("url", from: arguments),
                key: "url"
            ),
            availability: try parseAvailabilityValue(ToolArgumentParser.optionalString("availability", from: arguments)),
            alarms: try patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_alarms", from: arguments) ?? false,
                value: parseAlarmPatches(from: ToolArgumentParser.optionalObjectArray("alarms", from: arguments) ?? []),
                key: "alarms",
                valueWasProvided: arguments?["alarms"] != nil
            ),
            recurrence: try patchValue(
                clearFlag: ToolArgumentParser.optionalBool("clear_recurrence", from: arguments) ?? false,
                value: parseRecurrence(from: ToolArgumentParser.optionalObject("recurrence", from: arguments)),
                key: "recurrence"
            ),
            span: try parseSpan(from: arguments)
        )

        if case .set(let startDate) = patch.startDate,
            case .set(let endDate) = patch.endDate,
            startDate.date > endDate.date
        {
            throw ToolError.invalidArguments("start_date must be earlier than or equal to end_date")
        }

        return patch
    }

    private func parseRequiredEventDate(_ key: String, from arguments: [String: Value]?) throws -> EventDatePatch {
        guard let date = try parseOptionalEventDate(key, from: arguments) else {
            throw ToolError.invalidArguments("Missing required event date payload: \(key)")
        }
        return date
    }

    private func parseOptionalEventDate(_ key: String, from arguments: [String: Value]?) throws -> EventDatePatch? {
        try parseEventDate(from: ToolArgumentParser.optionalObject(key, from: arguments), key: key)
    }

    private func parseEventDate(from object: [String: Value]?, key: String) throws -> EventDatePatch? {
        guard let object else { return nil }
        guard let dateString = object["date"]?.stringValue, let date = DateFormatting.parse(dateString) else {
            throw ToolError.invalidArguments("Invalid event date payload for \(key).")
        }
        return EventDatePatch(
            date: date,
            allDay: object["all_day"]?.boolValue ?? false,
            timeZoneID: object["time_zone"]?.stringValue
        )
    }

    private func parseStructuredLocation(from object: [String: Value]?) throws -> EventStructuredLocationPatch? {
        guard let object else { return nil }
        guard let latitude = object["latitude"]?.doubleValue, let longitude = object["longitude"]?.doubleValue else {
            throw ToolError.invalidArguments("structured_location requires latitude and longitude.")
        }
        return EventStructuredLocationPatch(
            title: object["title"]?.stringValue,
            radius: object["radius"]?.doubleValue,
            latitude: latitude,
            longitude: longitude
        )
    }

    private func parseAlarmPatches(from array: [[String: Value]]) throws -> [EventAlarmPatch] {
        try array.map { object in
            EventAlarmPatch(
                absoluteDate: try parseOptionalDateValue(object["absolute_date"]),
                relativeOffset: object["relative_offset"]?.doubleValue,
                location: try parseStructuredLocation(from: object["location"]?.objectValue)
            )
        }
    }

    private func parseRecurrence(from object: [String: Value]?) throws -> EventRecurrencePatch? {
        guard let object else { return nil }
        guard let frequencyRaw = object["frequency"]?.stringValue,
            let frequency = EventFrequency(rawValue: frequencyRaw)
        else {
            throw ToolError.invalidArguments("recurrence.frequency must be one of daily, weekly, monthly, yearly")
        }
        return EventRecurrencePatch(
            frequency: frequency,
            interval: object["interval"]?.intValue ?? 1,
            endDate: try parseOptionalDateValue(object["end_date"]),
            occurrenceCount: object["occurrence_count"]?.intValue,
            daysOfWeek: object["days_of_week"]?.arrayValue?.compactMap { $0.stringValue }.compactMap(EventWeekday.init(rawValue:)) ?? [],
            daysOfMonth: object["days_of_month"]?.arrayValue?.compactMap(\.intValue) ?? [],
            monthsOfYear: object["months_of_year"]?.arrayValue?.compactMap(\.intValue) ?? [],
            setPositions: object["set_positions"]?.arrayValue?.compactMap(\.intValue) ?? []
        )
    }

    private func parseOptionalDateValue(_ value: Value?) throws -> Date? {
        guard let string = value?.stringValue else { return nil }
        guard let date = DateFormatting.parse(string) else {
            throw ToolError.invalidArguments("Invalid ISO-8601 date value.")
        }
        return date
    }

    private func parseSpan(from arguments: [String: Value]?) throws -> EventSpan {
        let raw = ToolArgumentParser.optionalString("span", from: arguments) ?? EventSpan.thisEvent.rawValue
        guard let span = EventSpan(rawValue: raw) else {
            throw ToolError.invalidArguments("span must be this_event or future_events")
        }
        return span
    }

    private func parseAvailabilityArray(from arguments: [String: Value]?) throws -> [EventAvailability] {
        try (ToolArgumentParser.optionalStringArray("availability_in", from: arguments) ?? []).map { raw in
            try parseAvailabilityValue(raw) ?? {
                throw ToolError.invalidArguments("Unsupported availability: \(raw)")
            }()
        }
    }

    private func parseStatusArray(from arguments: [String: Value]?) throws -> [EventStatus] {
        try (ToolArgumentParser.optionalStringArray("status_in", from: arguments) ?? []).map { raw in
            guard let status = EventStatus(rawValue: raw) else {
                throw ToolError.invalidArguments("Unsupported status: \(raw)")
            }
            return status
        }
    }

    private func parseAvailabilityValue(_ raw: String?) throws -> EventAvailability? {
        guard let raw else { return nil }
        guard let availability = EventAvailability(rawValue: raw) else {
            throw ToolError.invalidArguments("Unsupported availability: \(raw)")
        }
        return availability
    }

    private func requiredStringArray(_ key: String, from args: [String: Value]?) throws -> [String] {
        guard let values = ToolArgumentParser.optionalStringArray(key, from: args), !values.isEmpty else {
            throw ToolError.invalidArguments("Missing required string array argument: \(key)")
        }
        return values
    }

    private func patchValue<T>(clearFlag: Bool, value: T?, valueWasProvided: Bool = true) -> OptionalPatch<T>
    where T: Equatable & Sendable {
        if clearFlag {
            return .clear
        }
        if let value {
            return .set(value)
        }
        return valueWasProvided ? .unspecified : .unspecified
    }

    private func patchValue<T>(clearFlag: Bool, value: T?, key _: String, valueWasProvided: Bool = true) throws -> OptionalPatch<T>
    where T: Equatable & Sendable {
        patchValue(clearFlag: clearFlag, value: value, valueWasProvided: valueWasProvided)
    }
}

extension Value {
    fileprivate var objectValue: [String: Value]? {
        if case .object(let object) = self {
            return object
        }
        return nil
    }
}

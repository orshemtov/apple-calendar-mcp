import MCP

public struct ToolCatalog: Sendable {
    public let allTools: [Tool]

    public init() {
        self.allTools = [
            Self.listSources,
            Self.getDefaultCalendar,
            Self.listCalendars,
            Self.getCalendar,
            Self.createCalendar,
            Self.updateCalendar,
            Self.deleteCalendar,
            Self.listEvents,
            Self.listUpcomingEvents,
            Self.getEvent,
            Self.createEvent,
            Self.updateEvent,
            Self.bulkDeleteEvents,
            Self.bulkMoveEvents,
            Self.deleteEvent,
        ]
    }

    private static let listOutput = Schema.object(
        properties: [
            "success": Schema.boolean(),
            "message": Schema.string(),
            "item": Schema.object(properties: [:], additionalProperties: true),
            "items": Schema.array(items: Schema.object(properties: [:], additionalProperties: true)),
            "warnings": Schema.array(items: Schema.string()),
            "nextCursor": Schema.string(),
        ],
        additionalProperties: true
    )

    static let listSources = Tool(
        name: ToolName.listSources,
        description: "List calendar account sources available to the current macOS user.",
        inputSchema: Schema.object(properties: [:]),
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let getDefaultCalendar = Tool(
        name: ToolName.getDefaultCalendar,
        description: "Get the default calendar used for new events.",
        inputSchema: Schema.object(properties: [:]),
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let listCalendars = Tool(
        name: ToolName.listCalendars,
        description: "List event calendars with optional source and writability filters.",
        inputSchema: CalendarToolSchemas.listCalendars,
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let getCalendar = Tool(
        name: ToolName.getCalendar,
        description: "Get a calendar by identifier.",
        inputSchema: Schema.object(
            properties: ["calendar_id": Schema.string(description: "Calendar identifier")],
            required: ["calendar_id"]
        ),
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let createCalendar = Tool(
        name: ToolName.createCalendar,
        description: "Create a new calendar in the selected source.",
        inputSchema: Schema.object(
            properties: [
                "title": Schema.string(description: "New calendar title"),
                "source_id": Schema.string(description: "Optional source identifier for the new calendar"),
                "color_hex": Schema.string(description: "Optional calendar color as #RRGGBB or #RRGGBBAA"),
            ],
            required: ["title"]
        ),
        annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false),
        outputSchema: listOutput
    )

    static let updateCalendar = Tool(
        name: ToolName.updateCalendar,
        description: "Update an existing calendar title or color.",
        inputSchema: Schema.object(
            properties: [
                "calendar_id": Schema.string(description: "Calendar identifier"),
                "title": Schema.string(description: "Updated title for the calendar"),
                "color_hex": Schema.string(description: "Replacement calendar color as #RRGGBB or #RRGGBBAA"),
                "clear_color": Schema.boolean(description: "Remove any existing calendar color"),
            ],
            required: ["calendar_id"]
        ),
        annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let deleteCalendar = Tool(
        name: ToolName.deleteCalendar,
        description: "Delete a calendar by identifier.",
        inputSchema: Schema.object(
            properties: ["calendar_id": Schema.string(description: "Calendar identifier")],
            required: ["calendar_id"]
        ),
        annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let listEvents = Tool(
        name: ToolName.listEvents,
        description: "List events within a bounded time range with optional calendar and metadata filters.",
        inputSchema: CalendarToolSchemas.listEvents,
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let listUpcomingEvents = Tool(
        name: ToolName.listUpcomingEvents,
        description: "List upcoming events from now through an optional future bound.",
        inputSchema: CalendarToolSchemas.listUpcomingEvents,
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let getEvent = Tool(
        name: ToolName.getEvent,
        description: "Get an event by identifier.",
        inputSchema: Schema.object(
            properties: ["event_id": Schema.string(description: "Event identifier")],
            required: ["event_id"]
        ),
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let createEvent = Tool(
        name: ToolName.createEvent,
        description: "Create an event with start/end dates, optional alarms, recurrence, and location data.",
        inputSchema: CalendarToolSchemas.createEvent,
        annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false),
        outputSchema: listOutput
    )

    static let updateEvent = Tool(
        name: ToolName.updateEvent,
        description: "Update an existing event. Omitted fields are unchanged; clear_* flags remove values.",
        inputSchema: CalendarToolSchemas.updateEvent,
        annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let bulkDeleteEvents = Tool(
        name: ToolName.bulkDeleteEvents,
        description: "Delete multiple events, optionally as a dry run.",
        inputSchema: CalendarToolSchemas.bulkDelete,
        annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let bulkMoveEvents = Tool(
        name: ToolName.bulkMoveEvents,
        description: "Move multiple events to another calendar, optionally as a dry run.",
        inputSchema: CalendarToolSchemas.bulkMove,
        annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )

    static let deleteEvent = Tool(
        name: ToolName.deleteEvent,
        description: "Delete an event by identifier.",
        inputSchema: Schema.object(
            properties: [
                "event_id": Schema.string(description: "Event identifier"),
                "span": CalendarToolSchemas.spanSchema,
            ],
            required: ["event_id"]
        ),
        annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false),
        outputSchema: listOutput
    )
}

enum CalendarToolSchemas {
    static let date = Schema.object(
        properties: [
            "date": Schema.string(description: "ISO-8601 date or date-time"),
            "all_day": Schema.boolean(description: "Store the event date as all-day"),
            "time_zone": Schema.string(description: "Optional IANA time zone identifier; omit for floating dates"),
        ],
        required: ["date"]
    )

    static let structuredLocation = Schema.object(
        properties: [
            "title": Schema.string(description: "Human-readable location name"),
            "radius": Schema.number(description: "Optional geofence radius in meters"),
            "latitude": Schema.number(description: "Latitude in decimal degrees"),
            "longitude": Schema.number(description: "Longitude in decimal degrees"),
        ],
        required: ["latitude", "longitude"]
    )

    static let alarm = Schema.object(
        properties: [
            "absolute_date": Schema.string(description: "ISO-8601 absolute alarm date-time"),
            "relative_offset": Schema.number(description: "Relative offset in seconds from the event start date"),
            "location": structuredLocation,
        ]
    )

    static let recurrence = Schema.object(
        properties: [
            "frequency": Schema.string(enum: ["daily", "weekly", "monthly", "yearly"]),
            "interval": Schema.integer(description: "Repeat interval", minimum: 1),
            "end_date": Schema.string(description: "Optional ISO-8601 recurrence end date-time"),
            "occurrence_count": Schema.integer(description: "Optional number of occurrences", minimum: 1),
            "days_of_week": Schema.array(
                items: Schema.string(enum: [
                    "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
                ])),
            "days_of_month": Schema.array(items: Schema.integer()),
            "months_of_year": Schema.array(items: Schema.integer()),
            "set_positions": Schema.array(items: Schema.integer()),
        ],
        required: ["frequency"]
    )

    static let spanSchema = Schema.string(
        description: "Recurring-event mutation scope",
        enum: [EventSpan.thisEvent.rawValue, EventSpan.futureEvents.rawValue]
    )

    static let listCalendars = Schema.object(
        properties: [
            "source_ids": Schema.array(items: Schema.string(), description: "Optional source identifiers to filter by"),
            "writable_only": Schema.boolean(description: "Return only calendars that allow modifications"),
            "include_immutable": Schema.boolean(description: "Include immutable calendars in the result"),
            "include_subscribed": Schema.boolean(description: "Include subscribed calendars in the result"),
        ]
    )

    static let commonEventFilterProperties: [String: Value] = [
        "calendar_ids": Schema.array(items: Schema.string(), description: "Optional calendar identifiers to filter by"),
        "search": Schema.string(description: "Optional case-insensitive title, notes, or location search term"),
        "include_all_day": Schema.boolean(description: "Whether all-day events should be included"),
        "has_notes": Schema.boolean(description: "Filter by events that do or do not have notes"),
        "has_url": Schema.boolean(description: "Filter by events that do or do not have a URL"),
        "availability_in": Schema.array(
            items: Schema.string(enum: EventAvailability.allCases.map(\.rawValue)),
            description: "Optional list of availability values to include"
        ),
        "status_in": Schema.array(
            items: Schema.string(enum: EventStatus.allCases.map(\.rawValue)),
            description: "Optional list of event statuses to include"
        ),
        "only_detached": Schema.boolean(description: "Filter to detached recurring event instances only"),
        "limit": Schema.integer(description: "Maximum events to return", minimum: 1),
    ]

    static let listEvents = Schema.object(
        properties: commonEventFilterProperties.merging([
            "starting": Schema.string(description: "Required ISO-8601 lower bound for the event search window"),
            "ending": Schema.string(description: "Required ISO-8601 upper bound for the event search window"),
        ]) { current, _ in current },
        required: ["starting", "ending"]
    )

    static let listUpcomingEvents = Schema.object(
        properties: commonEventFilterProperties.merging([
            "starting": Schema.string(description: "Optional ISO-8601 lower bound; defaults to now"),
            "ending": Schema.string(description: "Optional ISO-8601 upper bound; defaults to 30 days from now"),
        ]) { current, _ in current }
    )

    static let createEvent = Schema.object(
        properties: [
            "calendar_id": Schema.string(
                description: "Optional target calendar identifier; defaults to the user's default calendar"),
            "title": Schema.string(description: "Event title"),
            "start_date": date,
            "end_date": date,
            "location": Schema.string(description: "Optional event location string"),
            "structured_location": structuredLocation,
            "notes": Schema.string(description: "Optional event notes"),
            "url": Schema.string(description: "Optional URL associated with the event"),
            "availability": Schema.string(
                description: "Optional event availability",
                enum: EventAvailability.allCases.map(\.rawValue)
            ),
            "alarms": Schema.array(items: alarm, description: "Optional time-based or location-based alarms"),
            "recurrence": recurrence,
        ],
        required: ["title", "start_date", "end_date"]
    )

    static let updateEvent = Schema.object(
        properties: [
            "event_id": Schema.string(description: "Event identifier"),
            "span": spanSchema,
            "calendar_id": Schema.string(description: "Optional new target calendar identifier"),
            "title": Schema.string(description: "Updated event title"),
            "start_date": date,
            "end_date": date,
            "location": Schema.string(description: "Replacement location value"),
            "clear_location": Schema.boolean(description: "Remove existing location"),
            "structured_location": structuredLocation,
            "clear_structured_location": Schema.boolean(description: "Remove existing structured location"),
            "notes": Schema.string(description: "Replacement notes value"),
            "clear_notes": Schema.boolean(description: "Remove existing notes"),
            "url": Schema.string(description: "Replacement URL value"),
            "clear_url": Schema.boolean(description: "Remove existing URL"),
            "availability": Schema.string(
                description: "Replacement availability value",
                enum: EventAvailability.allCases.map(\.rawValue)
            ),
            "alarms": Schema.array(items: alarm, description: "Replacement alarms array"),
            "clear_alarms": Schema.boolean(description: "Remove all alarms"),
            "recurrence": recurrence,
            "clear_recurrence": Schema.boolean(description: "Remove recurrence rules"),
        ],
        required: ["event_id"]
    )

    static let bulkDelete = Schema.object(
        properties: [
            "event_ids": Schema.array(items: Schema.string(), description: "Event identifiers to delete"),
            "span": spanSchema,
            "dry_run": Schema.boolean(description: "Preview the affected events without mutating them"),
        ],
        required: ["event_ids"]
    )

    static let bulkMove = Schema.object(
        properties: [
            "event_ids": Schema.array(items: Schema.string(), description: "Event identifiers to move"),
            "target_calendar_id": Schema.string(description: "Calendar identifier to move the events into"),
            "span": spanSchema,
            "dry_run": Schema.boolean(description: "Preview the affected events without mutating them"),
        ],
        required: ["event_ids", "target_calendar_id"]
    )
}

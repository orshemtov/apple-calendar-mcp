import Foundation

public struct CalendarSource: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let type: String
    public let calendarCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case calendarCount = "calendar_count"
    }
}

public struct EventCalendar: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourceID: String
    public let sourceTitle: String
    public let sourceType: String
    public let colorHex: String?
    public let allowsModifications: Bool
    public let isImmutable: Bool
    public let isSubscribed: Bool
    public let isDefault: Bool
    public let supportedAvailabilities: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case sourceType = "source_type"
        case colorHex = "color_hex"
        case allowsModifications = "allows_modifications"
        case isImmutable = "is_immutable"
        case isSubscribed = "is_subscribed"
        case isDefault = "is_default"
        case supportedAvailabilities = "supported_availabilities"
    }
}

public struct CalendarEvent: Codable, Equatable, Sendable {
    public let id: String
    public let externalID: String?
    public let calendarID: String
    public let calendarTitle: String
    public let sourceID: String
    public let sourceTitle: String
    public let title: String
    public let startDate: EventDate
    public let endDate: EventDate
    public let isAllDay: Bool
    public let timeZone: String?
    public let location: String?
    public let structuredLocation: EventStructuredLocation?
    public let notes: String?
    public let url: String?
    public let availability: String
    public let status: String
    public let occurrenceDate: String?
    public let isDetached: Bool
    public let alarms: [EventAlarm]
    public let recurrence: EventRecurrence?
    public let hasAlarms: Bool
    public let hasRecurrence: Bool
    public let organizer: EventParticipant?
    public let attendees: [EventParticipant]
    public let creationDate: String?
    public let lastModifiedDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case externalID = "external_id"
        case calendarID = "calendar_id"
        case calendarTitle = "calendar_title"
        case sourceID = "source_id"
        case sourceTitle = "source_title"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case isAllDay = "is_all_day"
        case timeZone = "time_zone"
        case location
        case structuredLocation = "structured_location"
        case notes
        case url
        case availability
        case status
        case occurrenceDate = "occurrence_date"
        case isDetached = "is_detached"
        case alarms
        case recurrence
        case hasAlarms = "has_alarms"
        case hasRecurrence = "has_recurrence"
        case organizer
        case attendees
        case creationDate = "creation_date"
        case lastModifiedDate = "last_modified_date"
    }
}

public struct EventDate: Codable, Equatable, Sendable {
    public let iso8601: String
    public let allDay: Bool
    public let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case iso8601
        case allDay = "all_day"
        case timeZone = "time_zone"
    }
}

public struct EventStructuredLocation: Codable, Equatable, Sendable {
    public let title: String?
    public let radius: Double?
    public let latitude: Double
    public let longitude: Double
}

public struct EventAlarm: Codable, Equatable, Sendable {
    public let absoluteDate: String?
    public let relativeOffset: Double?
    public let location: EventStructuredLocation?

    enum CodingKeys: String, CodingKey {
        case absoluteDate = "absolute_date"
        case relativeOffset = "relative_offset"
        case location
    }
}

public struct EventParticipant: Codable, Equatable, Sendable {
    public let name: String?
    public let url: String?
    public let role: String?
    public let status: String?
    public let type: String?
    public let isCurrentUser: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case role
        case status
        case type
        case isCurrentUser = "is_current_user"
    }
}

public struct EventRecurrence: Codable, Equatable, Sendable {
    public let frequency: String
    public let interval: Int
    public let endDate: String?
    public let occurrenceCount: Int?
    public let daysOfWeek: [String]?
    public let daysOfMonth: [Int]?
    public let monthsOfYear: [Int]?
    public let setPositions: [Int]?

    enum CodingKeys: String, CodingKey {
        case frequency
        case interval
        case endDate = "end_date"
        case occurrenceCount = "occurrence_count"
        case daysOfWeek = "days_of_week"
        case daysOfMonth = "days_of_month"
        case monthsOfYear = "months_of_year"
        case setPositions = "set_positions"
    }
}

public struct ToolEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let message: String
    public let item: T?
    public let items: [T]?
    public let warnings: [String]
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case item
        case items
        case warnings
        case nextCursor = "next_cursor"
    }

    public init(
        success: Bool = true,
        message: String,
        item: T? = nil,
        items: [T]? = nil,
        warnings: [String] = [],
        nextCursor: String? = nil
    ) {
        self.success = success
        self.message = message
        self.item = item
        self.items = items
        self.warnings = warnings
        self.nextCursor = nextCursor
    }
}

public struct EventMutationResult: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let event: CalendarEvent?
    public let deletedEventID: String?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case event
        case deletedEventID = "deleted_event_id"
        case warnings
    }
}

public struct CalendarMutationResult: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let calendar: EventCalendar?
    public let deletedCalendarID: String?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case calendar
        case deletedCalendarID = "deleted_calendar_id"
        case warnings
    }
}

public struct BulkEventMutationResult: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let dryRun: Bool
    public let affectedEvents: [CalendarEvent]
    public let targetCalendarID: String?
    public let span: String
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case dryRun = "dry_run"
        case affectedEvents = "affected_events"
        case targetCalendarID = "target_calendar_id"
        case span
        case warnings
    }
}

public struct EventQuery: Equatable, Sendable {
    public var calendarIDs: [String]
    public var starting: Date
    public var ending: Date
    public var search: String?
    public var includeAllDay: Bool?
    public var hasNotes: Bool?
    public var hasURL: Bool?
    public var availabilityIn: [EventAvailability]
    public var statusIn: [EventStatus]
    public var onlyDetached: Bool?
    public var limit: Int?

    public init(
        calendarIDs: [String] = [],
        starting: Date,
        ending: Date,
        search: String? = nil,
        includeAllDay: Bool? = nil,
        hasNotes: Bool? = nil,
        hasURL: Bool? = nil,
        availabilityIn: [EventAvailability] = [],
        statusIn: [EventStatus] = [],
        onlyDetached: Bool? = nil,
        limit: Int? = nil
    ) {
        self.calendarIDs = calendarIDs
        self.starting = starting
        self.ending = ending
        self.search = search
        self.includeAllDay = includeAllDay
        self.hasNotes = hasNotes
        self.hasURL = hasURL
        self.availabilityIn = availabilityIn
        self.statusIn = statusIn
        self.onlyDetached = onlyDetached
        self.limit = limit
    }
}

public struct EventPatch: Equatable, Sendable {
    public var calendarID: String?
    public var title: String?
    public var startDate: OptionalPatch<EventDatePatch>
    public var endDate: OptionalPatch<EventDatePatch>
    public var location: OptionalPatch<String>
    public var structuredLocation: OptionalPatch<EventStructuredLocationPatch>
    public var notes: OptionalPatch<String>
    public var url: OptionalPatch<URL>
    public var availability: EventAvailability?
    public var alarms: OptionalPatch<[EventAlarmPatch]>
    public var recurrence: OptionalPatch<EventRecurrencePatch>
    public var span: EventSpan

    public init(
        calendarID: String? = nil,
        title: String? = nil,
        startDate: OptionalPatch<EventDatePatch> = .unspecified,
        endDate: OptionalPatch<EventDatePatch> = .unspecified,
        location: OptionalPatch<String> = .unspecified,
        structuredLocation: OptionalPatch<EventStructuredLocationPatch> = .unspecified,
        notes: OptionalPatch<String> = .unspecified,
        url: OptionalPatch<URL> = .unspecified,
        availability: EventAvailability? = nil,
        alarms: OptionalPatch<[EventAlarmPatch]> = .unspecified,
        recurrence: OptionalPatch<EventRecurrencePatch> = .unspecified,
        span: EventSpan = .thisEvent
    ) {
        self.calendarID = calendarID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.structuredLocation = structuredLocation
        self.notes = notes
        self.url = url
        self.availability = availability
        self.alarms = alarms
        self.recurrence = recurrence
        self.span = span
    }
}

public struct EventCreateRequest: Equatable, Sendable {
    public let calendarID: String?
    public let title: String
    public let startDate: EventDatePatch
    public let endDate: EventDatePatch
    public let location: String?
    public let structuredLocation: EventStructuredLocationPatch?
    public let notes: String?
    public let url: URL?
    public let availability: EventAvailability?
    public let alarms: [EventAlarmPatch]
    public let recurrence: EventRecurrencePatch?

    public init(
        calendarID: String? = nil,
        title: String,
        startDate: EventDatePatch,
        endDate: EventDatePatch,
        location: String? = nil,
        structuredLocation: EventStructuredLocationPatch? = nil,
        notes: String? = nil,
        url: URL? = nil,
        availability: EventAvailability? = nil,
        alarms: [EventAlarmPatch] = [],
        recurrence: EventRecurrencePatch? = nil
    ) {
        self.calendarID = calendarID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.structuredLocation = structuredLocation
        self.notes = notes
        self.url = url
        self.availability = availability
        self.alarms = alarms
        self.recurrence = recurrence
    }
}

public struct CalendarCreateRequest: Equatable, Sendable {
    public let title: String
    public let sourceID: String?
    public let colorHex: String?

    public init(title: String, sourceID: String? = nil, colorHex: String? = nil) {
        self.title = title
        self.sourceID = sourceID
        self.colorHex = colorHex
    }
}

public struct CalendarPatch: Equatable, Sendable {
    public let title: String?
    public let colorHex: OptionalPatch<String>

    public init(title: String? = nil, colorHex: OptionalPatch<String> = .unspecified) {
        self.title = title
        self.colorHex = colorHex
    }
}

public struct EventDatePatch: Equatable, Sendable {
    public let date: Date
    public let allDay: Bool
    public let timeZoneID: String?

    public init(date: Date, allDay: Bool, timeZoneID: String? = nil) {
        self.date = date
        self.allDay = allDay
        self.timeZoneID = timeZoneID
    }
}

public struct EventStructuredLocationPatch: Equatable, Sendable {
    public let title: String?
    public let radius: Double?
    public let latitude: Double
    public let longitude: Double

    public init(title: String? = nil, radius: Double? = nil, latitude: Double, longitude: Double) {
        self.title = title
        self.radius = radius
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct EventAlarmPatch: Equatable, Sendable {
    public let absoluteDate: Date?
    public let relativeOffset: TimeInterval?
    public let location: EventStructuredLocationPatch?

    public init(
        absoluteDate: Date? = nil,
        relativeOffset: TimeInterval? = nil,
        location: EventStructuredLocationPatch? = nil
    ) {
        self.absoluteDate = absoluteDate
        self.relativeOffset = relativeOffset
        self.location = location
    }
}

public struct EventRecurrencePatch: Equatable, Sendable {
    public let frequency: EventFrequency
    public let interval: Int
    public let endDate: Date?
    public let occurrenceCount: Int?
    public let daysOfWeek: [EventWeekday]
    public let daysOfMonth: [Int]
    public let monthsOfYear: [Int]
    public let setPositions: [Int]

    public init(
        frequency: EventFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        occurrenceCount: Int? = nil,
        daysOfWeek: [EventWeekday] = [],
        daysOfMonth: [Int] = [],
        monthsOfYear: [Int] = [],
        setPositions: [Int] = []
    ) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
        self.daysOfWeek = daysOfWeek
        self.daysOfMonth = daysOfMonth
        self.monthsOfYear = monthsOfYear
        self.setPositions = setPositions
    }
}

public enum EventSpan: String, Codable, Equatable, Sendable {
    case thisEvent = "this_event"
    case futureEvents = "future_events"
}

public enum EventAvailability: String, Codable, CaseIterable, Equatable, Sendable {
    case notSupported = "not_supported"
    case busy
    case free
    case tentative
    case unavailable
}

public enum EventStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case none
    case confirmed
    case tentative
    case canceled
}

public enum EventFrequency: String, Codable, Equatable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}

public enum EventWeekday: String, Codable, CaseIterable, Equatable, Sendable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public enum OptionalPatch<Value: Equatable & Sendable>: Equatable, Sendable {
    case unspecified
    case set(Value)
    case clear
}

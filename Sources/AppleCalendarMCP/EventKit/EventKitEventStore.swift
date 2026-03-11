import CoreGraphics
import CoreLocation
@preconcurrency import EventKit
import Foundation

public actor EventKitEventStore: EventStoreProtocol {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func ensureAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .writeOnly, .denied, .restricted:
            throw ToolError.permissionDenied
        case .notDetermined:
            let granted = try await requestEventAccess()
            guard granted else {
                throw ToolError.permissionDenied
            }
        @unknown default:
            throw ToolError.permissionDenied
        }
    }

    public func sources() async throws -> [CalendarSource] {
        try await ensureAccess()
        return eventStore.sources
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map {
                CalendarSource(
                    id: $0.sourceIdentifier,
                    title: $0.title,
                    type: Self.sourceTypeString($0.sourceType),
                    calendarCount: $0.calendars(for: .event).count
                )
            }
    }

    public func defaultCalendar() async throws -> EventCalendar {
        try await ensureAccess()
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ToolError.noDefaultCalendar
        }
        return Self.makeCalendar(from: calendar, defaultID: calendar.calendarIdentifier)
    }

    public func calendars(sourceIDs: [String], writableOnly: Bool?, includeImmutable: Bool, includeSubscribed: Bool)
        async throws -> [EventCalendar]
    {
        try await ensureAccess()
        let defaultID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        return eventStore.calendars(for: .event)
            .filter { calendar in
                if !sourceIDs.isEmpty, !sourceIDs.contains(calendar.source.sourceIdentifier) {
                    return false
                }
                if !includeImmutable, calendar.isImmutable {
                    return false
                }
                if !includeSubscribed, calendar.isSubscribed {
                    return false
                }
                if writableOnly == true {
                    return calendar.allowsContentModifications && !calendar.isImmutable && !calendar.isSubscribed
                }
                return true
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { Self.makeCalendar(from: $0, defaultID: defaultID) }
    }

    public func calendar(id: String) async throws -> EventCalendar {
        try await ensureAccess()
        let calendar = try eventCalendar(id: id)
        return Self.makeCalendar(from: calendar, defaultID: eventStore.defaultCalendarForNewEvents?.calendarIdentifier)
    }

    public func createCalendar(_ request: CalendarCreateRequest) async throws -> EventCalendar {
        try await ensureAccess()
        let source = try sourceForNewCalendar(sourceID: request.sourceID)
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = request.title
        calendar.source = source
        if let cgColor = Self.cgColor(from: request.colorHex) {
            calendar.cgColor = cgColor
        }
        do {
            try eventStore.saveCalendar(calendar, commit: true)
        } catch {
            throw ToolError.eventKit(error.localizedDescription)
        }
        return try await self.calendar(id: calendar.calendarIdentifier)
    }

    public func updateCalendar(id: String, patch: CalendarPatch) async throws -> EventCalendar {
        try await ensureAccess()
        let calendar = try eventCalendar(id: id)
        try ensureWritable(calendar: calendar)

        if let title = patch.title {
            calendar.title = title
        }

        switch patch.colorHex {
        case .set(let colorHex):
            guard let cgColor = Self.cgColor(from: colorHex) else {
                throw ToolError.invalidArguments("Invalid hex color for calendar color.")
            }
            calendar.cgColor = cgColor
        case .clear:
            calendar.cgColor = nil
        case .unspecified:
            break
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
        } catch {
            throw ToolError.eventKit(error.localizedDescription)
        }

        return try await self.calendar(id: id)
    }

    public func deleteCalendar(id: String) async throws {
        try await ensureAccess()
        let calendar = try eventCalendar(id: id)
        try ensureWritable(calendar: calendar)
        do {
            try eventStore.removeCalendar(calendar, commit: true)
        } catch {
            throw ToolError.eventKit(error.localizedDescription)
        }
    }

    public func events(query: EventQuery) async throws -> [CalendarEvent] {
        try await ensureAccess()
        let calendars = try calendarsForIDs(query.calendarIDs)
        let predicate = eventStore.predicateForEvents(
            withStart: query.starting, end: query.ending, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        let filtered = events.filter { event in
            if let includeAllDay = query.includeAllDay, includeAllDay == false, event.isAllDay {
                return false
            }
            if let hasNotes = query.hasNotes, ((event.notes?.isEmpty) == false) != hasNotes {
                return false
            }
            if let hasURL = query.hasURL, (event.url != nil) != hasURL {
                return false
            }
            if !query.availabilityIn.isEmpty,
                !query.availabilityIn.contains(Self.makeAvailability(from: event.availability))
            {
                return false
            }
            if !query.statusIn.isEmpty,
                !query.statusIn.contains(Self.makeStatus(from: event.status))
            {
                return false
            }
            let isDetached = false
            if let onlyDetached = query.onlyDetached, isDetached != onlyDetached {
                return false
            }
            if let search = query.search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
                let haystack = [
                    event.title,
                    event.location ?? "",
                    event.structuredLocation?.title ?? "",
                    event.notes ?? "",
                ].joined(separator: "\n")
                if !haystack.localizedCaseInsensitiveContains(search) {
                    return false
                }
            }
            return true
        }
        .sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.startDate < rhs.startDate
        }

        let limited = query.limit.map { Array(filtered.prefix($0)) } ?? filtered
        return limited.map(Self.makeEvent(from:))
    }

    public func event(id: String) async throws -> CalendarEvent {
        try await ensureAccess()
        return Self.makeEvent(from: try eventEntity(id: id))
    }

    public func createEvent(_ request: EventCreateRequest) async throws -> CalendarEvent {
        try await ensureAccess()
        let event = EKEvent(eventStore: eventStore)
        event.calendar = try calendarForNewEvent(calendarID: request.calendarID)
        try ensureWritable(calendar: event.calendar)
        try applyCreateRequest(request, to: event)
        try save(event: event, span: .thisEvent)
        return Self.makeEvent(from: event)
    }

    public func updateEvent(id: String, patch: EventPatch) async throws -> CalendarEvent {
        try await ensureAccess()
        let event = try eventEntity(id: id)
        if let calendarID = patch.calendarID {
            event.calendar = try eventCalendar(id: calendarID)
        }
        try ensureWritable(calendar: event.calendar)
        try applyPatch(patch, to: event)
        try save(event: event, span: Self.ekSpan(from: patch.span))
        return Self.makeEvent(from: event)
    }

    public func deleteEvent(id: String, span: EventSpan) async throws {
        try await ensureAccess()
        let event = try eventEntity(id: id)
        try ensureWritable(calendar: event.calendar)
        do {
            try eventStore.remove(event, span: Self.ekSpan(from: span), commit: true)
        } catch {
            throw ToolError.eventKit(error.localizedDescription)
        }
    }

    public func bulkDeleteEvents(ids: [String], span: EventSpan, dryRun: Bool) async throws -> [CalendarEvent] {
        try await ensureAccess()
        let events = try ids.map(eventEntity(id:))
        for event in events {
            try ensureWritable(calendar: event.calendar)
        }
        let snapshots = events.map(Self.makeEvent(from:))
        if !dryRun {
            for event in events {
                do {
                    try eventStore.remove(event, span: Self.ekSpan(from: span), commit: true)
                } catch {
                    throw ToolError.eventKit(error.localizedDescription)
                }
            }
        }
        return snapshots
    }

    public func bulkMoveEvents(ids: [String], targetCalendarID: String, span: EventSpan, dryRun: Bool)
        async throws -> [CalendarEvent]
    {
        try await ensureAccess()
        let targetCalendar = try eventCalendar(id: targetCalendarID)
        try ensureWritable(calendar: targetCalendar)
        let events = try ids.map(eventEntity(id:))

        if dryRun {
            return events.map { Self.makeMovedPreview(from: $0, to: targetCalendar) }
        }

        for event in events {
            try ensureWritable(calendar: event.calendar)
            event.calendar = targetCalendar
            try save(event: event, span: Self.ekSpan(from: span))
        }

        return events.map(Self.makeEvent(from:))
    }

    private func requestEventAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: ToolError.eventKit(error.localizedDescription))
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: ToolError.eventKit(error.localizedDescription))
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func calendarsForIDs(_ ids: [String]) throws -> [EKCalendar]? {
        if ids.isEmpty {
            return nil
        }
        return try ids.map(eventCalendar(id:))
    }

    private func eventCalendar(id: String) throws -> EKCalendar {
        guard let calendar = eventStore.calendar(withIdentifier: id) else {
            throw ToolError.calendarNotFound(id)
        }
        return calendar
    }

    private func eventEntity(id: String) throws -> EKEvent {
        guard let event = eventStore.event(withIdentifier: id) else {
            throw ToolError.eventNotFound(id)
        }
        return event
    }

    private func calendarForNewEvent(calendarID: String?) throws -> EKCalendar {
        if let calendarID {
            return try eventCalendar(id: calendarID)
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ToolError.noDefaultCalendar
        }
        return calendar
    }

    private func sourceForNewCalendar(sourceID: String?) throws -> EKSource {
        if let sourceID {
            guard let source = eventStore.sources.first(where: { $0.sourceIdentifier == sourceID }) else {
                throw ToolError.invalidArguments("Calendar source not found: \(sourceID)")
            }
            return source
        }
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            return defaultSource
        }
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            return localSource
        }
        guard let first = eventStore.sources.first else {
            throw ToolError.invalidArguments("No calendar source is available for creating a new calendar.")
        }
        return first
    }

    private func ensureWritable(calendar: EKCalendar) throws {
        guard calendar.allowsContentModifications, !calendar.isImmutable, !calendar.isSubscribed else {
            throw ToolError.calendarNotWritable(calendar.calendarIdentifier)
        }
    }

    private func save(event: EKEvent, span: EKSpan) throws {
        do {
            try eventStore.save(event, span: span, commit: true)
        } catch {
            throw ToolError.eventKit(error.localizedDescription)
        }
    }

    private func applyCreateRequest(_ request: EventCreateRequest, to event: EKEvent) throws {
        event.title = request.title
        event.startDate = request.startDate.date
        event.endDate = request.endDate.date
        event.isAllDay = request.startDate.allDay || request.endDate.allDay
        event.timeZone = request.startDate.timeZoneID.flatMap(TimeZone.init(identifier:))
        event.location = request.location
        event.structuredLocation = request.structuredLocation.map(Self.makeStructuredLocation)
        event.notes = request.notes
        event.url = request.url
        if let availability = request.availability {
            event.availability = Self.ekAvailability(from: availability)
        }
        event.alarms = try request.alarms.map(Self.makeAlarm)
        event.recurrenceRules = try request.recurrence.map { [try Self.makeRecurrenceRule(from: $0)] }
    }

    private func applyPatch(_ patch: EventPatch, to event: EKEvent) throws {
        if let title = patch.title {
            event.title = title
        }

        switch patch.startDate {
        case .set(let startDate):
            event.startDate = startDate.date
            event.isAllDay = startDate.allDay
            event.timeZone = startDate.timeZoneID.flatMap(TimeZone.init(identifier:))
        case .clear, .unspecified:
            break
        }

        switch patch.endDate {
        case .set(let endDate):
            event.endDate = endDate.date
            event.isAllDay = event.isAllDay || endDate.allDay
            if let timeZoneID = endDate.timeZoneID {
                event.timeZone = TimeZone(identifier: timeZoneID)
            }
        case .clear, .unspecified:
            break
        }

        switch patch.location {
        case .set(let location):
            event.location = location
        case .clear:
            event.location = nil
        case .unspecified:
            break
        }

        switch patch.structuredLocation {
        case .set(let location):
            event.structuredLocation = Self.makeStructuredLocation(location)
        case .clear:
            event.structuredLocation = nil
        case .unspecified:
            break
        }

        switch patch.notes {
        case .set(let notes):
            event.notes = notes
        case .clear:
            event.notes = nil
        case .unspecified:
            break
        }

        switch patch.url {
        case .set(let url):
            event.url = url
        case .clear:
            event.url = nil
        case .unspecified:
            break
        }

        if let availability = patch.availability {
            event.availability = Self.ekAvailability(from: availability)
        }

        switch patch.alarms {
        case .set(let alarms):
            event.alarms = try alarms.map(Self.makeAlarm)
        case .clear:
            event.alarms = nil
        case .unspecified:
            break
        }

        switch patch.recurrence {
        case .set(let recurrence):
            event.recurrenceRules = [try Self.makeRecurrenceRule(from: recurrence)]
        case .clear:
            event.recurrenceRules = nil
        case .unspecified:
            break
        }

        guard event.startDate <= event.endDate else {
            throw ToolError.invalidArguments("start_date must be earlier than or equal to end_date")
        }
    }

    private static func makeCalendar(from calendar: EKCalendar, defaultID: String?) -> EventCalendar {
        EventCalendar(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceID: calendar.source.sourceIdentifier,
            sourceTitle: calendar.source.title,
            sourceType: sourceTypeString(calendar.source.sourceType),
            colorHex: ColorFormatting.normalizedHexString(from: String(describing: calendar.cgColor)),
            allowsModifications: calendar.allowsContentModifications,
            isImmutable: calendar.isImmutable,
            isSubscribed: calendar.isSubscribed,
            isDefault: calendar.calendarIdentifier == defaultID,
            supportedAvailabilities: supportedAvailabilities(for: calendar)
        )
    }

    private static func makeEvent(from event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier,
            externalID: event.calendarItemExternalIdentifier,
            calendarID: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            sourceID: event.calendar.source.sourceIdentifier,
            sourceTitle: event.calendar.source.title,
            title: event.title,
            startDate: makeEventDate(date: event.startDate, allDay: event.isAllDay, timeZone: event.timeZone),
            endDate: makeEventDate(date: event.endDate, allDay: event.isAllDay, timeZone: event.timeZone),
            isAllDay: event.isAllDay,
            timeZone: event.timeZone?.identifier,
            location: event.location,
            structuredLocation: event.structuredLocation.map(makeStructuredLocation),
            notes: event.notes,
            url: event.url?.absoluteString,
            availability: makeAvailability(from: event.availability).rawValue,
            status: makeStatus(from: event.status).rawValue,
            occurrenceDate: nil,
            isDetached: false,
            alarms: (event.alarms ?? []).map(makeAlarm),
            recurrence: event.recurrenceRules?.first.map(makeRecurrence),
            hasAlarms: event.alarms?.isEmpty == false,
            hasRecurrence: event.recurrenceRules?.isEmpty == false,
            organizer: event.organizer.map(makeParticipant),
            attendees: (event.attendees ?? []).map(makeParticipant),
            creationDate: event.creationDate.map(DateFormatting.string),
            lastModifiedDate: event.lastModifiedDate.map(DateFormatting.string)
        )
    }

    private static func makeMovedPreview(from event: EKEvent, to calendar: EKCalendar) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier,
            externalID: event.calendarItemExternalIdentifier,
            calendarID: calendar.calendarIdentifier,
            calendarTitle: calendar.title,
            sourceID: calendar.source.sourceIdentifier,
            sourceTitle: calendar.source.title,
            title: event.title,
            startDate: makeEventDate(date: event.startDate, allDay: event.isAllDay, timeZone: event.timeZone),
            endDate: makeEventDate(date: event.endDate, allDay: event.isAllDay, timeZone: event.timeZone),
            isAllDay: event.isAllDay,
            timeZone: event.timeZone?.identifier,
            location: event.location,
            structuredLocation: event.structuredLocation.map(makeStructuredLocation),
            notes: event.notes,
            url: event.url?.absoluteString,
            availability: makeAvailability(from: event.availability).rawValue,
            status: makeStatus(from: event.status).rawValue,
            occurrenceDate: nil,
            isDetached: false,
            alarms: (event.alarms ?? []).map(makeAlarm),
            recurrence: event.recurrenceRules?.first.map(makeRecurrence),
            hasAlarms: event.alarms?.isEmpty == false,
            hasRecurrence: event.recurrenceRules?.isEmpty == false,
            organizer: event.organizer.map(makeParticipant),
            attendees: (event.attendees ?? []).map(makeParticipant),
            creationDate: event.creationDate.map(DateFormatting.string),
            lastModifiedDate: event.lastModifiedDate.map(DateFormatting.string)
        )
    }

    private static func makeEventDate(date: Date, allDay: Bool, timeZone: TimeZone?) -> EventDate {
        EventDate(
            iso8601: DateFormatting.string(from: date),
            allDay: allDay,
            timeZone: timeZone?.identifier
        )
    }

    private static func makeStructuredLocation(_ location: EKStructuredLocation) -> EventStructuredLocation {
        EventStructuredLocation(
            title: location.title,
            radius: location.radius,
            latitude: location.geoLocation?.coordinate.latitude ?? 0,
            longitude: location.geoLocation?.coordinate.longitude ?? 0
        )
    }

    private static func makeStructuredLocation(_ patch: EventStructuredLocationPatch) -> EKStructuredLocation {
        let structuredLocation = EKStructuredLocation(title: patch.title ?? "Location")
        structuredLocation.geoLocation = CLLocation(latitude: patch.latitude, longitude: patch.longitude)
        if let radius = patch.radius {
            structuredLocation.radius = radius
        }
        return structuredLocation
    }

    private static func makeAlarm(_ alarm: EKAlarm) -> EventAlarm {
        EventAlarm(
            absoluteDate: alarm.absoluteDate.map(DateFormatting.string),
            relativeOffset: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
            location: alarm.structuredLocation.map(makeStructuredLocation)
        )
    }

    private static func makeAlarm(_ patch: EventAlarmPatch) throws -> EKAlarm {
        let alarm: EKAlarm
        if let absoluteDate = patch.absoluteDate {
            alarm = EKAlarm(absoluteDate: absoluteDate)
        } else {
            alarm = EKAlarm(relativeOffset: patch.relativeOffset ?? 0)
        }
        if let location = patch.location {
            alarm.structuredLocation = makeStructuredLocation(location)
        }
        return alarm
    }

    private static func makeRecurrence(_ recurrence: EKRecurrenceRule) -> EventRecurrence {
        EventRecurrence(
            frequency: frequencyString(recurrence.frequency),
            interval: recurrence.interval,
            endDate: recurrence.recurrenceEnd?.endDate.map(DateFormatting.string),
            occurrenceCount: recurrence.recurrenceEnd?.occurrenceCount,
            daysOfWeek: recurrence.daysOfTheWeek?.map { weekdayString($0.dayOfTheWeek) },
            daysOfMonth: recurrence.daysOfTheMonth?.map(\.intValue),
            monthsOfYear: recurrence.monthsOfTheYear?.map(\.intValue),
            setPositions: recurrence.setPositions?.map(\.intValue)
        )
    }

    private static func makeRecurrenceRule(from recurrence: EventRecurrencePatch) throws -> EKRecurrenceRule {
        guard recurrence.interval > 0 else {
            throw ToolError.invalidArguments("recurrence.interval must be greater than 0")
        }
        let end: EKRecurrenceEnd?
        if let occurrenceCount = recurrence.occurrenceCount {
            end = EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        } else if let endDate = recurrence.endDate {
            end = EKRecurrenceEnd(end: endDate)
        } else {
            end = nil
        }
        return EKRecurrenceRule(
            recurrenceWith: frequency(from: recurrence.frequency),
            interval: recurrence.interval,
            daysOfTheWeek: recurrence.daysOfWeek.isEmpty ? nil : recurrence.daysOfWeek.map(dayOfWeek),
            daysOfTheMonth: recurrence.daysOfMonth.isEmpty ? nil : recurrence.daysOfMonth.map(NSNumber.init(value:)),
            monthsOfTheYear: recurrence.monthsOfYear.isEmpty ? nil : recurrence.monthsOfYear.map(NSNumber.init(value:)),
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: recurrence.setPositions.isEmpty ? nil : recurrence.setPositions.map(NSNumber.init(value:)),
            end: end
        )
    }

    private static func makeParticipant(_ participant: EKParticipant) -> EventParticipant {
        EventParticipant(
            name: participant.name,
            url: participant.url.absoluteString,
            role: participantRoleString(participant.participantRole),
            status: participantStatusString(participant.participantStatus),
            type: participantTypeString(participant.participantType),
            isCurrentUser: participant.isCurrentUser
        )
    }

    private static func makeAvailability(from availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return .notSupported
        @unknown default:
            return .notSupported
        }
    }

    private static func makeStatus(from status: EKEventStatus) -> EventStatus {
        switch status {
        case .none:
            return .none
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .canceled:
            return .canceled
        @unknown default:
            return .none
        }
    }

    private static func supportedAvailabilities(for calendar: EKCalendar) -> [String] {
        let mask = calendar.supportedEventAvailabilities
        var values: [String] = []
        if mask.contains(.busy) { values.append(EventAvailability.busy.rawValue) }
        if mask.contains(.free) { values.append(EventAvailability.free.rawValue) }
        if mask.contains(.tentative) { values.append(EventAvailability.tentative.rawValue) }
        if mask.contains(.unavailable) { values.append(EventAvailability.unavailable.rawValue) }
        if values.isEmpty { values.append(EventAvailability.notSupported.rawValue) }
        return values
    }

    private static func ekAvailability(from availability: EventAvailability) -> EKEventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return .notSupported
        }
    }

    private static func ekSpan(from span: EventSpan) -> EKSpan {
        switch span {
        case .thisEvent:
            return .thisEvent
        case .futureEvents:
            return .futureEvents
        }
    }

    private static func dayOfWeek(_ weekday: EventWeekday) -> EKRecurrenceDayOfWeek {
        switch weekday {
        case .sunday:
            return EKRecurrenceDayOfWeek(.sunday)
        case .monday:
            return EKRecurrenceDayOfWeek(.monday)
        case .tuesday:
            return EKRecurrenceDayOfWeek(.tuesday)
        case .wednesday:
            return EKRecurrenceDayOfWeek(.wednesday)
        case .thursday:
            return EKRecurrenceDayOfWeek(.thursday)
        case .friday:
            return EKRecurrenceDayOfWeek(.friday)
        case .saturday:
            return EKRecurrenceDayOfWeek(.saturday)
        }
    }

    private static func frequency(from frequency: EventFrequency) -> EKRecurrenceFrequency {
        switch frequency {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }

    private static func frequencyString(_ frequency: EKRecurrenceFrequency) -> String {
        switch frequency {
        case .daily:
            return EventFrequency.daily.rawValue
        case .weekly:
            return EventFrequency.weekly.rawValue
        case .monthly:
            return EventFrequency.monthly.rawValue
        case .yearly:
            return EventFrequency.yearly.rawValue
        @unknown default:
            return EventFrequency.daily.rawValue
        }
    }

    private static func weekdayString(_ day: EKWeekday) -> String {
        switch day {
        case .sunday:
            return EventWeekday.sunday.rawValue
        case .monday:
            return EventWeekday.monday.rawValue
        case .tuesday:
            return EventWeekday.tuesday.rawValue
        case .wednesday:
            return EventWeekday.wednesday.rawValue
        case .thursday:
            return EventWeekday.thursday.rawValue
        case .friday:
            return EventWeekday.friday.rawValue
        case .saturday:
            return EventWeekday.saturday.rawValue
        @unknown default:
            return EventWeekday.monday.rawValue
        }
    }

    private static func participantRoleString(_ role: EKParticipantRole) -> String? {
        switch role {
        case .chair:
            return "chair"
        case .required:
            return "required"
        case .optional:
            return "optional"
        case .nonParticipant:
            return "non_participant"
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func participantStatusString(_ status: EKParticipantStatus) -> String? {
        switch status {
        case .pending:
            return "pending"
        case .accepted:
            return "accepted"
        case .declined:
            return "declined"
        case .tentative:
            return "tentative"
        case .delegated:
            return "delegated"
        case .completed:
            return "completed"
        case .inProcess:
            return "in_process"
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func participantTypeString(_ type: EKParticipantType) -> String? {
        switch type {
        case .person:
            return "person"
        case .room:
            return "room"
        case .resource:
            return "resource"
        case .group:
            return "group"
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func sourceTypeString(_ sourceType: EKSourceType) -> String {
        switch sourceType {
        case .local:
            return "local"
        case .exchange:
            return "exchange"
        case .calDAV:
            return "caldav"
        case .mobileMe:
            return "mobileme"
        case .subscribed:
            return "subscribed"
        case .birthdays:
            return "birthdays"
        @unknown default:
            return "unknown"
        }
    }

    private static func cgColor(from hex: String?) -> CGColor? {
        guard let hex else { return nil }
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 || sanitized.count == 8, let value = UInt64(sanitized, radix: 16) else {
            return nil
        }
        let redShift = sanitized.count == 8 ? 24 : 16
        let greenShift = sanitized.count == 8 ? 16 : 8
        let blueShift = sanitized.count == 8 ? 8 : 0
        let alpha = sanitized.count == 8 ? CGFloat(value & 0xFF) / 255 : 1
        let red = CGFloat((value >> redShift) & 0xFF) / 255
        let green = CGFloat((value >> greenShift) & 0xFF) / 255
        let blue = CGFloat((value >> blueShift) & 0xFF) / 255
        return CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

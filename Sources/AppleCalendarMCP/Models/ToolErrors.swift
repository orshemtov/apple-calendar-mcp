import Foundation

public enum ToolError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case noDefaultCalendar
    case invalidArguments(String)
    case calendarNotFound(String)
    case eventNotFound(String)
    case calendarNotWritable(String)
    case unsupported(String)
    case eventKit(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access is not granted. Allow this executable to access Calendars in System Settings."
        case .noDefaultCalendar:
            return "No default calendar is configured for new events, and no calendar_id was provided."
        case .invalidArguments(let message):
            return message
        case .calendarNotFound(let id):
            return "Calendar not found: \(id)"
        case .eventNotFound(let id):
            return "Event not found: \(id)"
        case .calendarNotWritable(let id):
            return "Calendar is read-only, subscribed, or immutable: \(id)"
        case .unsupported(let message):
            return message
        case .eventKit(let message):
            return message
        }
    }
}

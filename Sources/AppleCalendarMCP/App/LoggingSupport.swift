import Logging

public enum LoggingSupport {
    public static func bootstrap() {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }
    }

    public static func makeLogger(label: String = "com.or.apple-calendar-mcp") -> Logger {
        Logger(label: label)
    }
}

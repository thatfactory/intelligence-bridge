import AppLogger

enum IntelligenceBridgeLogging {
    static let emoji = "🧠"
    static let subsystem = "com.thatfactory.intelligencebridge"

    enum Event: Equatable {
        case cancelled
        case completed
        case dismissed
        case invalidated
        case launchFailed(ImagePlaygroundBridgeLaunchFailure)
        case opened
        case opening

        var message: String {
            switch self {
            case .cancelled:
                "\(emoji) playground | result=cancelled"
            case .completed:
                "\(emoji) playground | result=completed"
            case .dismissed:
                "\(emoji) playground | result=dismissed"
            case .invalidated:
                "\(emoji) playground | result=invalidated"
            case .launchFailed(let reason):
                "\(emoji) playground | result=launch-failed reason=\(reason == .timedOut ? "timed-out" : "unavailable")"
            case .opened:
                "\(emoji) playground | result=opened"
            case .opening:
                "\(emoji) playground | result=opening"
            }
        }
    }

    static func emit(_ event: Event) {
        let logger = AppLogger(subsystem: subsystem, category: "presentation")
        if case .launchFailed = event {
            logger.log(level: .error, event.message)
        } else {
            logger.log(level: .debug, event.message)
        }
    }
}

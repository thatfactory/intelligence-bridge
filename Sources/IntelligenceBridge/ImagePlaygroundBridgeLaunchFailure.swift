/// A failure to open the native editor. Generation inside an opened editor has no deadline.
public enum ImagePlaygroundBridgeLaunchFailure: Equatable, Sendable {
    /// The native editor did not finish opening before the opening deadline.
    case timedOut

    /// The current device cannot present Image Playground.
    case unavailable
}

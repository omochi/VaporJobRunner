import Vapor

public struct JobContext {
    public init(
        id: UUID,
        eventLoop: EventLoop,
        logger: Logger
    ) {
        self.id = id
        self.eventLoop = eventLoop
        self.logger = logger
    }

    public var id: UUID
    public var eventLoop: EventLoop
    public var logger: Logger
}

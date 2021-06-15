import Vapor

public protocol JobProtocol {
    func run(context: JobContext) throws -> EventLoopFuture<Void>
}

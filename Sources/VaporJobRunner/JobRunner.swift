import Vapor

public final class JobRunner {
    private let queue: DispatchQueue
    private let eventLoopGroup: EventLoopGroup
    private let logger: Logger

    private var tickTimer: DispatchSourceTimer?

    private var scheduledJobs: [ScheduledJob] = []

    public init(eventLoopGroup: EventLoopGroup) {
        self.queue = DispatchQueue(label: "JobRunner")
        self.eventLoopGroup = eventLoopGroup
        self.logger = Logger(label: "JobRunner")
    }

    public func start() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            scheduleNextTick0()
        }
    }

    public func stop() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        tickTimer = nil
    }

    @discardableResult
    public func dispatch<J>(job: J) -> UUID
    where J: JobProtocol
    {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            dispatch0(job: job)
        }
    }

    fileprivate func dispatch0<J>(
        job: J,
        id: UUID? = nil,
        completion: (() -> Void)? = nil
    ) -> UUID
    where J: JobProtocol
    {
        dispatchPrecondition(condition: .onQueue(queue))

        let id = id ?? UUID()
        let eventLoop = eventLoopGroup.next()
        var logger = Logger(label: "\(J.self)")
        logger[metadataKey: "job-id"] = .string(id.uuidString)
        let context = JobContext(
            id: id,
            eventLoop: eventLoop,
            logger: logger
        )
        eventLoop.execute {
            let run = eventLoop.tryFuture {
                try job.run(context: context)
            }.flatMap { $0 }

            _ = run.flatMapError { (error) in
                logger.error("error: \(error)")
                return eventLoop.future()
            }.always { (_) in
                completion?()
            }
        }
        return id
    }

    @discardableResult
    public func schedule<J>(job: J, date: ScheduleDate) throws -> UUID
    where J: JobProtocol
    {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return try queue.sync {
            try schedule0(job: job, date: date)
        }
    }

    private func schedule0<J>(job: J, date: ScheduleDate) throws -> UUID
    where J: JobProtocol
    {
        dispatchPrecondition(condition: .onQueue(queue))

        let id = UUID()
        guard let next = date.next(now: Date()) else {
            throw MessageError(description: "invalid schedule: \(date)")
        }

        let scheduledJob = ScheduledJob(
            id: id,
            job: job,
            schedule: date,
            next: next,
            isRunning: false
        )
        scheduledJobs.append(scheduledJob)
        return id
    }

    public func removeScheduledJob(id: UUID) {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            removeScheduledJob0(id: id)
        }
    }

    private func removeScheduledJob0(id: UUID) {
        dispatchPrecondition(condition: .notOnQueue(queue))
        
        scheduledJobs.removeAll { $0.id == id }
    }

    private func scheduleNextTick0() {
        dispatchPrecondition(condition: .onQueue(queue))

        let timer = DispatchSource.makeTimerSource(
            flags: [],
            queue: queue
        )
        self.tickTimer = timer
        timer.setEventHandler { [weak self] in
            self?.tick0()
        }
        timer.schedule(deadline: .now() + .seconds(1))
        timer.resume()
    }

    private func tick0() {
        dispatchPrecondition(condition: .onQueue(queue))

        let now = Date()
        for i in scheduledJobs.indices {
            var sj = scheduledJobs[i]
            guard !sj.isRunning,
                  sj.next <= now else { continue }
            sj.isRunning = true
            _ = sj.job.dispatch(
                runner: self,
                completion: { [weak self] in
                    self?.onScheduledJobComplete(
                        id: sj.id,
                        startDate: sj.next
                    )
                }
            )
            scheduledJobs[i] = sj
        }

        scheduleNextTick0()
    }

    private func onScheduledJobComplete(
        id: UUID,
        startDate: Date
    ) {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            onScheduledJobComplete0(
                id: id,
                startDate: startDate
            )
        }
    }

    private func onScheduledJobComplete0(
        id: UUID,
        startDate: Date
    ) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let i = (scheduledJobs.firstIndex { $0.id == id }) else { return }
        var sj = scheduledJobs[i]
        sj.isRunning = false

        let now = max(Date(), startDate)
        guard let next = sj.schedule.next(now: now) else {
            logger.error("invalid schedule: \(sj.schedule), job=\(type(of: sj.job)), id=\(sj.id)")
            removeScheduledJob0(id: id)
            return
        }
        sj.next = next
        scheduledJobs[i] = sj
    }
}

extension JobProtocol {
    func dispatch(
        runner: JobRunner,
        completion: (() -> Void)? = nil
    ) -> UUID {
        runner.dispatch0(
            job: self,
            completion: completion
        )
    }
}

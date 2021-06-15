import XCTest
import Vapor
import VaporJobRunner

struct JobRunnerKey: StorageKey {
    typealias Value = JobRunner
}

struct AJob: JobProtocol {
    var f: () -> Void

    func run(context: JobContext) throws -> EventLoopFuture<Void> {
        f()
        return context.eventLoop.future()
    }
}

struct BJob: JobProtocol {
    var f: () -> Void

    func run(context: JobContext) throws -> EventLoopFuture<Void> {
        f()
        return context.eventLoop.future()
    }
}

func configure(
    app: Application
) {
    let runner = JobRunner(eventLoopGroup: app.eventLoopGroup)

    app.storage[JobRunnerKey.self] = runner

    app.routes.get("shutdown") { (request) -> String in
        request.application.running?.stop()
        return ""
    }
}

final class VaporJobRunnerTests: XCTestCase {
    func test1() {
        let expAppStop = expectation(description: "appStop")

        let app = Application(.testing)
        defer { app.shutdown() }
        configure(app: app)

        var runner: JobRunner {
            app.storage[JobRunnerKey.self]!
        }

        var aCount = 0

        app.routes.get("AJob") { (request) -> String in
            runner.dispatch(job: AJob {
                print("A")
                aCount += 1
            })

            return ""
        }

        var bCount = 0

        app.routes.get("BJob") { (request) -> String in
            try runner.schedule(
                job: BJob {
                    print("B begin")
                    bCount += 1
                    for _ in 0..<12 {
                        usleep(100 * 1000)
                    }
                    print("B end")
                },
                date: ScheduleDate(
                    millisecond: 0
                )
            )

            return ""
        }

        app.routes.get("stop") { (_) -> String in
            runner.stop()
            return ""
        }

        runner.start()

        DispatchQueue.global().async {
            try! app.run()
            expAppStop.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            _ = app.client.get("http://localhost:8080/AJob")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
            _ = app.client.get("http://localhost:8080/BJob")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(8)) {
            _ = app.client.get("http://localhost:8080/shutdown")
        }

        wait(for: [expAppStop], timeout: .infinity)
        XCTAssertEqual(aCount, 1)
        XCTAssertEqual(bCount, 3)
    }
}

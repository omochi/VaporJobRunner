import Foundation

struct ScheduledJob {
    var id: UUID
    var job: JobProtocol
    var schedule: ScheduleDate
    var next: Date
    var isRunning: Bool
}

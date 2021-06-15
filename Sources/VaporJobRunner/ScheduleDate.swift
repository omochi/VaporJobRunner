import Foundation

public struct ScheduleDate: CustomStringConvertible {
    public init(hour: Int? = nil, minute: Int? = nil, second: Int? = nil, millisecond: Int? = nil) {
        self.hour = hour
        self.minute = minute
        self.second = second
        self.millisecond = millisecond
    }

    public var hour: Int?
    public var minute: Int?
    public var second: Int?
    public var millisecond: Int?

    public var description: String {
        var strs: [String] = []
        if let hour = hour {
            strs.append("hour=\(hour)")
        }
        if let minute = minute {
            strs.append("minute=\(minute)")
        }
        if let second = second {
            strs.append("second=\(second)")
        }
        if let ms = millisecond {
            strs.append("millisecond=\(ms)")
        }
        return "(" + strs.joined(separator: ", ") + ")"
    }

    public func next(now: Date) -> Date? {
        var dc = DateComponents()

        if let hour = self.hour {
            dc.hour = hour
        }
        if let minute = self.minute {
            dc.minute = minute
        }
        if let second = self.second {
            dc.second = second
        }
        if let ms = self.millisecond {
            dc.nanosecond = ms * 1000
        }

        return Calendar.current.nextDate(
            after: now,
            matching: dc,
            matchingPolicy: .strict
        )
    }
}

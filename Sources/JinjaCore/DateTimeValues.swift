import Foundation
@_exported import OrderedCollections

/// Magic object keys for datetime / timedelta values (blocked from template access by
/// ``DefaultAttributePolicy`` because they are `_`-prefixed).
enum JinjaDateTimeKeys {
    static let datetimeEpoch = "__jinja_datetime_epoch__"
    static let datetimeTZ = "__jinja_datetime_tz__"
    static let timedeltaSeconds = "__jinja_timedelta_seconds__"
}

extension Value {
    /// Builds an HA/Python-like datetime object: attributes (`hour`, …) plus methods
    /// resolved via ``PropertyMembers`` (`isoformat()`, `date()`, …).
    public static func datetime(_ date: Date, timeZone: TimeZone) -> Value {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday],
            from: date
        )
        var dict = OrderedDictionary<ObjectKey, Value>()
        dict[.string(JinjaDateTimeKeys.datetimeEpoch)] = .double(date.timeIntervalSince1970)
        dict[.string(JinjaDateTimeKeys.datetimeTZ)] = .string(timeZone.identifier)
        dict[.string("year")] = .int(parts.year ?? 0)
        dict[.string("month")] = .int(parts.month ?? 0)
        dict[.string("day")] = .int(parts.day ?? 0)
        dict[.string("hour")] = .int(parts.hour ?? 0)
        dict[.string("minute")] = .int(parts.minute ?? 0)
        dict[.string("second")] = .int(parts.second ?? 0)
        let micro = (parts.nanosecond ?? 0) / 1000
        dict[.string("microsecond")] = .int(micro)
        // Python: Monday=0 … Sunday=6. Calendar weekday: Sunday=1 … Saturday=7.
        let pythonWeekday: Int = {
            let wd = parts.weekday ?? 1
            return (wd + 5) % 7
        }()
        dict[.string("weekday")] = .int(pythonWeekday)

        let display = formatJinjaDateTime(date, timeZone: timeZone)
        return .object(dict, stringRepresentation: display)
    }

    /// Builds a timedelta-like object (seconds stored; `total_seconds()` via PropertyMembers).
    public static func timedelta(seconds: Double) -> Value {
        let total = seconds
        let days = Int(total / 86_400)
        let rem = total - Double(days) * 86_400
        let secs = Int(rem)
        let micros = Int(((rem - Double(secs)) * 1_000_000).rounded())
        var dict = OrderedDictionary<ObjectKey, Value>()
        dict[.string(JinjaDateTimeKeys.timedeltaSeconds)] = .double(total)
        dict[.string("days")] = .int(days)
        dict[.string("seconds")] = .int(secs)
        dict[.string("microseconds")] = .int(micros)
        return .object(dict, stringRepresentation: formatJinjaTimedelta(seconds: total))
    }

    /// Extracts a `Date` from a datetime object or numeric/string timestamp value.
    public var dateTimeDate: Date? {
        if case .object(let dict, _, _) = self,
           case .double(let epoch) = dict[.string(JinjaDateTimeKeys.datetimeEpoch)]
        {
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }

    public var dateTimeTimeZone: TimeZone? {
        if case .object(let dict, _, _) = self,
           case .string(let id) = dict[.string(JinjaDateTimeKeys.datetimeTZ)]
        {
            return TimeZone(identifier: id)
        }
        return nil
    }

    public var isJinjaDateTime: Bool {
        dateTimeDate != nil
    }

    public var timedeltaSeconds: Double? {
        if case .object(let dict, _, _) = self,
           case .double(let seconds) = dict[.string(JinjaDateTimeKeys.timedeltaSeconds)]
        {
            return seconds
        }
        return nil
    }

    public var isJinjaTimedelta: Bool {
        timedeltaSeconds != nil
    }
}

func formatJinjaDateTime(_ date: Date, timeZone: TimeZone) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = timeZone
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func formatJinjaTimedelta(seconds: Double) -> String {
    // Python-ish: "1 day, 0:00:01" / "0:01:00"
    let sign = seconds < 0 ? "-" : ""
    var remaining = abs(seconds)
    let days = Int(remaining / 86_400)
    remaining -= Double(days) * 86_400
    let hours = Int(remaining / 3_600)
    remaining -= Double(hours) * 3_600
    let minutes = Int(remaining / 60)
    let secs = remaining - Double(minutes) * 60
    let timePart = String(format: "%d:%02d:%02g", hours, minutes, secs)
    if days != 0 {
        let unit = abs(days) == 1 ? "day" : "days"
        return "\(sign)\(days) \(unit), \(timePart)"
    }
    return "\(sign)\(timePart)"
}

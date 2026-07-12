import Foundation
@testable import HackersPub
import Testing

struct DateFormatHelperTests {
    private let english = Locale(identifier: "en_US")

    @Test func parsesFractionalAndWholeSecondISO8601Timestamps() {
        let calendar = gregorianCalendar(in: .gmt)
        let now = date(.init(2025, 1, 1, 12, 0), calendar: calendar)

        let wholeSecond = DateFormatHelper.relativeTime(
            from: "2025-01-01T11:59:00Z",
            now: now,
            calendar: calendar,
            locale: english
        )
        let fractionalSecond = DateFormatHelper.relativeTime(
            from: "2025-01-01T11:59:00.500Z",
            now: now,
            calendar: calendar,
            locale: english
        )

        #expect(wholeSecond == "1 minute ago")
        #expect(fractionalSecond == "less than a minute ago")
    }

    @Test func invalidBackendTimestampsUseLocalizedFallbackInsteadOfRawValues() {
        let calendar = gregorianCalendar(in: .gmt)
        let rawTimestamp = "not-a-date-from-the-backend"

        let relative = DateFormatHelper.relativeTime(
            from: rawTimestamp,
            now: date(.init(2025, 1, 1, 12, 0), calendar: calendar),
            calendar: calendar,
            locale: english
        )
        let full = DateFormatHelper.fullDateTime(
            from: rawTimestamp,
            calendar: calendar,
            locale: english
        )

        #expect(relative == "Date unavailable")
        #expect(full == "Date unavailable")
        #expect(!relative.contains(rawTimestamp))
        #expect(!full.contains(rawTimestamp))
    }

    @Test func injectedLocaleControlsRelativeAndFullDateFormatting() {
        let calendar = gregorianCalendar(in: .gmt)
        let now = date(.init(2025, 1, 1, 12, 0), calendar: calendar)
        let korean = Locale(identifier: "ko_KR")
        let timestamp = "2025-01-01T11:59:00Z"

        #expect(
            DateFormatHelper.relativeTime(
                from: timestamp,
                now: now,
                calendar: calendar,
                locale: korean
            ) == "1분 전"
        )

        let instant = date(.init(2025, 1, 1, 11, 59), calendar: calendar)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = korean
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        #expect(
            DateFormatHelper.fullDateTime(
                from: timestamp,
                calendar: calendar,
                locale: korean
            ) == formatter.string(from: instant)
        )
    }

    @Test func futureAndExactMinuteHourBoundariesDoNotProduceNegativePastTense() {
        let calendar = gregorianCalendar(in: .gmt)
        let now = date(.init(2025, 1, 1, 12, 0), calendar: calendar)

        #expect(
            DateFormatHelper.relativeTime(
                from: "2025-01-01T12:01:00Z",
                now: now,
                calendar: calendar,
                locale: english
            ) == "less than a minute ago"
        )
        #expect(
            DateFormatHelper.relativeTime(
                from: "2025-01-01T11:59:00Z",
                now: now,
                calendar: calendar,
                locale: english
            ) == "1 minute ago"
        )
        #expect(
            DateFormatHelper.relativeTime(
                from: "2025-01-01T11:00:00Z",
                now: now,
                calendar: calendar,
                locale: english
            ) == "1 hour ago"
        )
    }

    @Test func calendarUnitsRespectDSTMonthAndLeapYearBoundaries() throws {
        let pacific = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let calendar = gregorianCalendar(in: pacific)

        let daylightSavingNow = date(.init(2025, 3, 10, 12, 0), calendar: calendar)
        #expect(
            DateFormatHelper.relativeTime(
                from: "2025-03-09T19:00:00Z",
                now: daylightSavingNow,
                calendar: calendar,
                locale: english
            ) == "1 day ago"
        )

        let monthNow = date(.init(2025, 3, 31, 12, 0), calendar: calendar)
        #expect(
            DateFormatHelper.relativeTime(
                from: "2025-02-28T20:00:00Z",
                now: monthNow,
                calendar: calendar,
                locale: english
            ) == "1 month ago"
        )

        let leapYearNow = date(.init(2025, 2, 28, 12, 0), calendar: calendar)
        #expect(
            DateFormatHelper.relativeTime(
                from: "2024-02-29T20:00:00Z",
                now: leapYearNow,
                calendar: calendar,
                locale: english
            ) == "1 year ago"
        )
    }

    @Test func timelineAndDetailDateLabelsUseTheSharedSafeFormatter() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let consumers = [
            "HackersPub/Views/PostView.swift",
            "HackersPub/Views/NotificationRowView.swift",
            "HackersPub/Views/PostDetailView.swift",
            "HackersPub/Views/ArticleDetailView.swift",
            "HackersPub/Views/ArticleViews.swift"
        ]

        for consumer in consumers {
            let source = try String(
                contentsOf: repositoryRoot.appending(path: consumer),
                encoding: .utf8
            )
            #expect(source.contains("DateFormatHelper."))
        }
    }
}

private func gregorianCalendar(in timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    return calendar
}

private struct DateFields {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int

    init(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }
}

private func date(_ fields: DateFields, calendar: Calendar) -> Date {
    calendar.date(
        from: DateComponents(
            timeZone: calendar.timeZone,
            year: fields.year,
            month: fields.month,
            day: fields.day,
            hour: fields.hour,
            minute: fields.minute
        )
    )!
}

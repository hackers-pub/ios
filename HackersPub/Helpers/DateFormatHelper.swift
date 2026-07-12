import Foundation

enum DateFormatHelper {
    private struct RelativeTimeUnit {
        let component: Calendar.Component
        let singularKey: String
        let pluralKey: String
    }

    /// Converts an ISO 8601 timestamp to localized relative time.
    static func relativeTime(
        from isoString: String,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let date = parseISO8601(isoString) else {
            return localizedString(for: "date.unavailable", locale: locale)
        }

        guard date <= now else {
            return localizedString(for: "date.lessThanMinute", locale: locale)
        }

        let units: [RelativeTimeUnit] = [
            RelativeTimeUnit(component: .year, singularKey: "date.yearAgo", pluralKey: "date.yearsAgo"),
            RelativeTimeUnit(component: .month, singularKey: "date.monthAgo", pluralKey: "date.monthsAgo"),
            RelativeTimeUnit(component: .weekOfYear, singularKey: "date.weekAgo", pluralKey: "date.weeksAgo"),
            RelativeTimeUnit(component: .day, singularKey: "date.dayAgo", pluralKey: "date.daysAgo"),
            RelativeTimeUnit(component: .hour, singularKey: "date.hourAgo", pluralKey: "date.hoursAgo"),
            RelativeTimeUnit(component: .minute, singularKey: "date.minuteAgo", pluralKey: "date.minutesAgo")
        ]

        for unit in units {
            let count = completedUnits(of: unit.component, from: date, to: now, calendar: calendar)
            guard count > 0 else { continue }

            if count == 1 {
                return localizedString(for: unit.singularKey, locale: locale)
            }
            return String(
                format: localizedString(for: unit.pluralKey, locale: locale),
                locale: locale,
                count
            )
        }

        return localizedString(for: "date.lessThanMinute", locale: locale)
    }

    /// Converts an ISO 8601 timestamp to localized full date and time.
    static func fullDateTime(
        from isoString: String,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let date = parseISO8601(isoString) else {
            return localizedString(for: "date.unavailable", locale: locale)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func completedUnits(
        of component: Calendar.Component,
        from date: Date,
        to now: Date,
        calendar: Calendar
    ) -> Int {
        var count = max(
            0,
            calendar.dateComponents([component], from: date, to: now).value(for: component) ?? 0
        )

        // swiftlint:disable opening_brace
        while let next = calendar.date(byAdding: component, value: count + 1, to: date),
              next <= now
        {
            count += 1
        }

        while count > 0,
              let candidate = calendar.date(byAdding: component, value: count, to: date),
              candidate > now
        {
            count -= 1
        }
        // swiftlint:enable opening_brace

        return count
    }

    private static func localizedString(for key: String, locale: Locale) -> String {
        let languageCode = locale.identifier.split(separator: "_").first.map(String.init)
        let localizedBundle = languageCode.flatMap {
            Bundle.main.url(forResource: $0, withExtension: "lproj").flatMap(Bundle.init(url:))
        }
        let value = (localizedBundle ?? .main).localizedString(forKey: key, value: nil, table: nil)

        if value != key {
            return value
        }
        if key == "date.unavailable" {
            return "Date unavailable"
        }
        return key
    }

    private static func parseISO8601(_ isoString: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let fractionalDate = fractionalFormatter.date(from: isoString) {
            return fractionalDate
        }

        let wholeSecondFormatter = ISO8601DateFormatter()
        wholeSecondFormatter.formatOptions = [.withInternetDateTime]
        return wholeSecondFormatter.date(from: isoString)
    }
}

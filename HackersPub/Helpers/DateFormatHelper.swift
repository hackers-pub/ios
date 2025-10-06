import Foundation

struct DateFormatHelper {
    /// Converts ISO 8601 timestamp to relative time (e.g., "2 minutes ago")
    static func relativeTime(from isoString: String) -> String {
        guard let date = parseISO8601(isoString) else {
            return isoString
        }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Less than a minute
        if interval < 60 {
            return NSLocalizedString("date.lessThanMinute", comment: "Time interval less than a minute")
        }

        // Minutes
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1
                ? NSLocalizedString("date.minuteAgo", comment: "One minute ago")
                : String(format: NSLocalizedString("date.minutesAgo", comment: "Multiple minutes ago"), minutes)
        }

        // Hours
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1
                ? NSLocalizedString("date.hourAgo", comment: "One hour ago")
                : String(format: NSLocalizedString("date.hoursAgo", comment: "Multiple hours ago"), hours)
        }

        // Days
        if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1
                ? NSLocalizedString("date.dayAgo", comment: "One day ago")
                : String(format: NSLocalizedString("date.daysAgo", comment: "Multiple days ago"), days)
        }

        // Weeks
        if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return weeks == 1
                ? NSLocalizedString("date.weekAgo", comment: "One week ago")
                : String(format: NSLocalizedString("date.weeksAgo", comment: "Multiple weeks ago"), weeks)
        }

        // Months
        if interval < 31536000 {
            let months = Int(interval / 2592000)
            return months == 1
                ? NSLocalizedString("date.monthAgo", comment: "One month ago")
                : String(format: NSLocalizedString("date.monthsAgo", comment: "Multiple months ago"), months)
        }

        // Years
        let years = Int(interval / 31536000)
        return years == 1
            ? NSLocalizedString("date.yearAgo", comment: "One year ago")
            : String(format: NSLocalizedString("date.yearsAgo", comment: "Multiple years ago"), years)
    }

    /// Converts ISO 8601 timestamp to full formatted date and time
    static func fullDateTime(from isoString: String) -> String {
        guard let date = parseISO8601(isoString) else {
            return isoString
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Parse ISO 8601 date string
    private static func parseISO8601(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: isoString)
    }
}

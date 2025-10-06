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
            return "less than a minute ago"
        }

        // Minutes
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }

        // Hours
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }

        // Days
        if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        // Weeks
        if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }

        // Months
        if interval < 31536000 {
            let months = Int(interval / 2592000)
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }

        // Years
        let years = Int(interval / 31536000)
        return years == 1 ? "1 year ago" : "\(years) years ago"
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

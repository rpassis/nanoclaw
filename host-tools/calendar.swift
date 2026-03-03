#!/usr/bin/env swift
/**
 * Calendar management using macOS EventKit framework
 * Native Swift implementation for maximum performance and reliability
 */

import EventKit
import Foundation

let store = EKEventStore()

// Request calendar access
func requestAccess() -> Bool {
    var granted = false
    let semaphore = DispatchSemaphore(value: 0)

    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { (accessGranted, error) in
            granted = accessGranted
            semaphore.signal()
        }
    } else {
        store.requestAccess(to: .event) { (accessGranted, error) in
            granted = accessGranted
            semaphore.signal()
        }
    }

    semaphore.wait()

    if !granted {
        printError("Calendar access denied. Grant permission in System Settings > Privacy & Security > Calendars")
        exit(1)
    }

    return granted
}

// Helper to print errors
func printError(_ message: String) {
    fputs("Error: \(message)\n", stderr)
}

// Format event for display
func formatEvent(_ event: EKEvent) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none

    let timeStr = formatter.string(from: event.startDate)
    var result = "\(timeStr) - \(event.title ?? "Untitled")"

    if let notes = event.notes, !notes.isEmpty {
        result += " (\(notes))"
    }

    return result
}

// Parse date string (supports "today", "tomorrow", "+N days", "YYYY-MM-DD")
func parseDate(_ dateStr: String, time: String = "00:00") -> Date? {
    let calendar = Calendar.current
    var date: Date

    switch dateStr.lowercased() {
    case "today":
        date = Date()
    case "tomorrow":
        date = calendar.date(byAdding: .day, value: 1, to: Date())!
    default:
        if dateStr.hasPrefix("+") {
            let components = dateStr.dropFirst().split(separator: " ")
            guard components.count == 2,
                  let num = Int(components[0]) else {
                return nil
            }

            let unit = String(components[1])
            if unit.contains("day") {
                date = calendar.date(byAdding: .day, value: num, to: Date())!
            } else if unit.contains("week") {
                date = calendar.date(byAdding: .weekOfYear, value: num, to: Date())!
            } else {
                return nil
            }
        } else {
            // Parse YYYY-MM-DD
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let parsed = formatter.date(from: dateStr) else {
                return nil
            }
            date = parsed
        }
    }

    // Apply time if provided
    if !time.isEmpty {
        let components = time.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        date = calendar.date(from: dateComponents)!
    }

    return date
}

// Parse duration string (e.g., "1h", "30m", "1h30m")
func parseDuration(_ durationStr: String) -> Int {
    var totalMinutes = 0
    var remaining = durationStr

    // Extract hours
    if let hRange = remaining.range(of: "h") {
        let hourStr = remaining[..<hRange.lowerBound]
        totalMinutes += (Int(hourStr) ?? 0) * 60
        remaining = String(remaining[hRange.upperBound...])
    }

    // Extract minutes
    if let mRange = remaining.range(of: "m") {
        let minStr = remaining[..<mRange.lowerBound]
        totalMinutes += Int(minStr) ?? 0
    }

    return totalMinutes > 0 ? totalMinutes : 60 // Default 1 hour
}

// List events for N days
func listEvents(days: Int = 7) {
    let calendar = Calendar.current
    let now = Date()
    let end = calendar.date(byAdding: .day, value: days, to: now)!

    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
    let events = store.events(matching: predicate)

    if events.isEmpty {
        print("No events in the next \(days) days")
        return
    }

    // Group by date
    var eventsByDate: [String: [EKEvent]] = [:]
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    for event in events {
        let dateKey = dateFormatter.string(from: event.startDate)
        eventsByDate[dateKey, default: []].append(event)
    }

    // Print grouped by date
    let displayFormatter = DateFormatter()
    displayFormatter.dateFormat = "EEEE, MMMM dd, yyyy"

    for dateKey in eventsByDate.keys.sorted() {
        guard let date = dateFormatter.date(from: dateKey),
              let events = eventsByDate[dateKey] else { continue }

        print("\n\(displayFormatter.string(from: date)):")
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        for event in sortedEvents {
            print("  \(formatEvent(event))")
        }
    }
}

// List today's events
func listToday() {
    let calendar = Calendar.current
    let now = Date()
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start)!

    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM dd, yyyy"

    if events.isEmpty {
        print("No events today")
        return
    }

    print("Today (\(formatter.string(from: now))):")
    for event in events {
        print("  \(formatEvent(event))")
    }
}

// List tomorrow's events
func listTomorrow() {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    let start = calendar.startOfDay(for: tomorrow)
    let end = calendar.date(byAdding: .day, value: 1, to: start)!

    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM dd, yyyy"

    if events.isEmpty {
        print("No events tomorrow")
        return
    }

    print("Tomorrow (\(formatter.string(from: tomorrow))):")
    for event in events {
        print("  \(formatEvent(event))")
    }
}

// List available calendars
func listCalendars() {
    let calendars = store.calendars(for: .event)
    if calendars.isEmpty {
        print("No calendars found")
        return
    }
    let defaultCal = store.defaultCalendarForNewEvents
    print("Available calendars:")
    for cal in calendars.sorted(by: { $0.title < $1.title }) {
        let marker = cal.calendarIdentifier == defaultCal?.calendarIdentifier ? " (default)" : ""
        print("  \(cal.title)\(marker)")
    }
}

// Add a new event
func addEvent(title: String, dateStr: String, timeStr: String, durationStr: String = "1h", notes: String = "", calendarName: String = "") {
    let calendar: EKCalendar?
    if calendarName.isEmpty {
        calendar = store.defaultCalendarForNewEvents
    } else {
        calendar = store.calendars(for: .event).first(where: { $0.title == calendarName })
        if calendar == nil {
            printError("Calendar '\(calendarName)' not found. Run 'calendars' to list available calendars.")
            exit(1)
        }
    }

    guard let cal = calendar else {
        printError("No default calendar found")
        exit(1)
    }

    guard let startDate = parseDate(dateStr, time: timeStr) else {
        printError("Invalid date or time format")
        exit(1)
    }

    let event = EKEvent(eventStore: store)
    event.title = title
    event.calendar = cal
    event.startDate = startDate

    let durationMinutes = parseDuration(durationStr)
    event.endDate = startDate.addingTimeInterval(Double(durationMinutes * 60))

    if !notes.isEmpty {
        event.notes = notes
    }

    do {
        try store.save(event, span: .thisEvent)
        print("Created: \(title) on \(dateStr) at \(timeStr) for \(durationStr) in '\(cal.title)'")
    } catch {
        printError("Failed to create event: \(error.localizedDescription)")
        exit(1)
    }
}

// Search events by title
func searchEvents(query: String) {
    let calendar = Calendar.current
    let now = Date()
    let end = calendar.date(byAdding: .year, value: 1, to: now)!

    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
    let allEvents = store.events(matching: predicate)

    let matching = allEvents.filter { event in
        event.title?.lowercased().contains(query.lowercased()) ?? false
    }

    if matching.isEmpty {
        print("No events found matching: \(query)")
        return
    }

    print("Found \(matching.count) event(s) matching '\(query)':")
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    for event in matching.sorted(by: { $0.startDate < $1.startDate }) {
        print("  \(formatter.string(from: event.startDate)) - \(event.title ?? "Untitled")")
    }
}

// Update an existing event
func updateEvent(
    currentTitle: String,
    newTitle: String?,
    dateStr: String?,
    timeStr: String?,
    durationStr: String?,
    notes: String?,
    calendarName: String?
) {
    let calInstance = Calendar.current
    let now = Date()
    let end = calInstance.date(byAdding: .year, value: 1, to: now)!

    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
    let matching = store.events(matching: predicate).filter { $0.title == currentTitle }

    if matching.isEmpty {
        printError("No event found with title: \(currentTitle)")
        exit(1)
    }

    var updatedCount = 0
    for event in matching {
        if let newTitle = newTitle {
            event.title = newTitle
        }

        // Handle date/time changes — preserve whichever dimension is not being changed
        if dateStr != nil || timeStr != nil {
            let currentDateFmt = DateFormatter()
            currentDateFmt.dateFormat = "yyyy-MM-dd"
            let currentTimeFmt = DateFormatter()
            currentTimeFmt.dateFormat = "HH:mm"

            let targetDate = dateStr ?? currentDateFmt.string(from: event.startDate)
            let targetTime = timeStr ?? currentTimeFmt.string(from: event.startDate)

            if let newStart = parseDate(targetDate, time: targetTime) {
                let originalDuration = event.endDate.timeIntervalSince(event.startDate)
                event.startDate = newStart
                if let durationStr = durationStr {
                    let minutes = parseDuration(durationStr)
                    event.endDate = newStart.addingTimeInterval(Double(minutes * 60))
                } else {
                    event.endDate = newStart.addingTimeInterval(originalDuration)
                }
            }
        } else if let durationStr = durationStr {
            let minutes = parseDuration(durationStr)
            event.endDate = event.startDate.addingTimeInterval(Double(minutes * 60))
        }

        if let notes = notes {
            event.notes = notes.isEmpty ? nil : notes
        }

        if let calendarName = calendarName {
            guard let newCal = store.calendars(for: .event).first(where: { $0.title == calendarName }) else {
                printError("Calendar '\(calendarName)' not found. Run 'calendars' to list available calendars.")
                exit(1)
            }
            event.calendar = newCal
        }

        do {
            try store.save(event, span: .thisEvent)
            updatedCount += 1
        } catch {
            printError("Failed to update event: \(error.localizedDescription)")
        }
    }

    let displayTitle = newTitle ?? currentTitle
    print("Updated \(updatedCount) event(s): '\(displayTitle)'")
}

// Delete event by exact title
func deleteEvent(title: String) {
    let calendar = Calendar.current
    let now = Date()
    let end = calendar.date(byAdding: .year, value: 1, to: now)!

    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
    let allEvents = store.events(matching: predicate)

    let matching = allEvents.filter { $0.title == title }

    if matching.isEmpty {
        print("No event found with title: \(title)")
        return
    }

    var deleted = 0
    for event in matching {
        do {
            try store.remove(event, span: .thisEvent)
            deleted += 1
        } catch {
            printError("Failed to delete event: \(error.localizedDescription)")
        }
    }

    print("Deleted \(deleted) event(s): \(title)")
}

// Main
let args = CommandLine.arguments

if args.count < 2 {
    printError("Usage: calendar <command> [args...]")
    exit(1)
}

// Request access first
_ = requestAccess()

let command = args[1]

switch command {
case "list":
    let days = args.count > 2 ? Int(args[2]) ?? 7 : 7
    listEvents(days: days)

case "today":
    listToday()

case "tomorrow":
    listTomorrow()

case "calendars":
    listCalendars()

case "add":
    guard args.count >= 5 else {
        printError("Usage: calendar add <title> <date> <time> [duration] [notes] [calendarName]")
        exit(1)
    }
    let title = args[2]
    let dateStr = args[3]
    let timeStr = args[4]
    let duration = args.count > 5 ? args[5] : "1h"
    let notes = args.count > 6 ? args[6] : ""
    let calendarName = args.count > 7 ? args[7] : ""
    addEvent(title: title, dateStr: dateStr, timeStr: timeStr, durationStr: duration, notes: notes, calendarName: calendarName)

case "update":
    guard args.count >= 3 else {
        printError("Usage: calendar update <currentTitle> [--title <new>] [--date <date>] [--time <time>] [--duration <dur>] [--notes <notes>] [--calendar <name>]")
        exit(1)
    }
    let currentTitle = args[2]
    var newTitle: String? = nil
    var updateDate: String? = nil
    var updateTime: String? = nil
    var updateDuration: String? = nil
    var updateNotes: String? = nil
    var updateCalendar: String? = nil

    var i = 3
    while i < args.count {
        if i + 1 < args.count {
            switch args[i] {
            case "--title":    newTitle = args[i+1];        i += 2
            case "--date":     updateDate = args[i+1];     i += 2
            case "--time":     updateTime = args[i+1];     i += 2
            case "--duration": updateDuration = args[i+1]; i += 2
            case "--notes":    updateNotes = args[i+1];    i += 2
            case "--calendar": updateCalendar = args[i+1]; i += 2
            default: i += 1
            }
        } else {
            i += 1
        }
    }
    updateEvent(currentTitle: currentTitle, newTitle: newTitle, dateStr: updateDate, timeStr: updateTime, durationStr: updateDuration, notes: updateNotes, calendarName: updateCalendar)

case "search":
    guard args.count >= 3 else {
        printError("Usage: calendar search <query>")
        exit(1)
    }
    searchEvents(query: args[2])

case "delete":
    guard args.count >= 3 else {
        printError("Usage: calendar delete <title>")
        exit(1)
    }
    deleteEvent(title: args[2])

default:
    printError("Unknown command: \(command)")
    exit(1)
}

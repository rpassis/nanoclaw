# calendar - Apple Calendar Management

Manage calendar events in the user's Apple Calendar app.

## Usage

```bash
calendar today                    # Show today's events
calendar tomorrow                 # Show tomorrow's events
calendar list [days]              # List upcoming events (default: 7 days)
calendar calendars                # List available calendars
calendar add <title> <date> <time> [duration] [notes] [--calendar <name>]
calendar search <query>           # Search events by title
calendar delete <event-title>     # Delete event by title
```

## Examples

### List Events

```bash
# Next 7 days
calendar list

# Next 14 days
calendar list 14

# Today's events
calendar today

# Tomorrow's events
calendar tomorrow
```

### Add Events

```bash
# Add to default calendar
calendar add "Team meeting" "2026-03-05" "14:00" "1h" "Discuss Q1 goals"

# Add to a specific calendar
calendar add "Dentist" "tomorrow" "9:30" "30m" --calendar "Personal"

# Add with notes to a specific calendar
calendar add "Conference" "2026-03-10" "09:00" "8h" "Annual tech conf" --calendar "Work"

# Relative dates
calendar add "Review docs" "+3 days" "15:00" "2h"
```

### List Calendars

```bash
# Show all available calendars (with default marked)
calendar calendars
```

### Search & Delete

```bash
# Find events
calendar search "meeting"

# Delete by exact title
calendar delete "Team meeting"
```

## Date Formats

- **Absolute**: `YYYY-MM-DD` (e.g., `2026-03-05`)
- **Relative**: `today`, `tomorrow`, `+3 days`, `+1 week`

## Time Format

- **24-hour**: `HH:MM` (e.g., `14:00`, `09:30`)

## Duration Format

- `30m` - 30 minutes
- `1h` - 1 hour
- `1h30m` - 1.5 hours
- `2h` - 2 hours

## Environment Variables

- `CALENDAR_NAME` - Which calendar to use (default: "Calendar")

## Important Notes

- **Timezone**: User is in Australia/Brisbane (AEST/AEDT)
- **First run**: macOS will prompt for Calendar access permission (user needs to grant it)
- **Delete**: Deletes by exact title match - be precise
- **Multiple calendars**: Searches all calendars, adds to the default calendar

## Permission Required

On first use, macOS will ask the user to grant Calendar access to Terminal/Docker. The user needs to:
1. System Settings → Privacy & Security → Automation
2. Allow Terminal (or Docker) to control Calendar

## Examples for User Requests

**"Add a meeting tomorrow at 2pm"**
```bash
calendar add "Meeting" "tomorrow" "14:00" "1h"
```

**"What's on my calendar today?"**
```bash
calendar today
```

**"Schedule dentist appointment for March 15 at 9:30am"**
```bash
calendar add "Dentist appointment" "2026-03-15" "09:30" "30m"
```

**"Show my schedule for the next 2 weeks"**
```bash
calendar list 14
```

**"Cancel the team meeting"**
```bash
calendar delete "Team meeting"
```

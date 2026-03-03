---
name: google-calendar
description: Create, modify, and manage Google Calendar events. Find meeting times when attendees are available using FreeBusy queries.
---

# Google Calendar Skill

Manage Google Calendar events using gcloud CLI + curl. This skill provides patterns and utilities for creating meetings with Google Meet links, managing attendees, searching events, attaching documents, handling recurring meetings, and **finding available meeting times** when multiple attendees need to meet.

## Authentication

**Run `/google-auth` first** to authenticate with Google Workspace, or use the shared auth module:

```bash
# Check authentication status
python3 ../google-auth/resources/google_auth.py status

# Login if needed
python3 ../google-auth/resources/google_auth.py login

# Get access token for API calls
TOKEN=$(python3 ../google-auth/resources/google_auth.py token)
```

All Google skills share the same authentication. See `/google-auth` for details on scopes and troubleshooting.

### Quota Project

All API calls require a quota project header:

```bash
-H "x-goog-user-project: gcp-sandbox-field-eng"
```

## Core Concepts

### Calendar IDs

- `primary` - The user's primary calendar
- Email addresses can be used as calendar IDs for shared calendars
- Calendar IDs are unique identifiers for each calendar

### Event Times

All times use RFC 3339 format with timezone:
- `2025-01-15T10:00:00-08:00` (Pacific time)
- `2025-01-15T18:00:00Z` (UTC)

For all-day events, use date format:
- `2025-01-15` (all-day event)

### Event IDs

Each event has a unique ID used for updates, deletions, and queries.

## API Reference

### Base URL

```
https://www.googleapis.com/calendar/v3
```

## Creating Events

### Create Simple Event

```bash
TOKEN=$(gcloud auth application-default print-access-token)

curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Team Meeting",
    "description": "Weekly team sync",
    "start": {
      "dateTime": "2025-01-15T10:00:00-08:00",
      "timeZone": "America/Los_Angeles"
    },
    "end": {
      "dateTime": "2025-01-15T11:00:00-08:00",
      "timeZone": "America/Los_Angeles"
    }
  }'
```

### Create Event with Google Meet Link (Default for New Meetings)

```bash
curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Team Meeting",
    "description": "Weekly team sync",
    "start": {
      "dateTime": "2025-01-15T10:00:00-08:00",
      "timeZone": "America/Los_Angeles"
    },
    "end": {
      "dateTime": "2025-01-15T11:00:00-08:00",
      "timeZone": "America/Los_Angeles"
    },
    "attendees": [
      {"email": "brandon@databricks.com"},
      {"email": "bkvarda@squareup.com"}
    ],
    "conferenceData": {
      "createRequest": {
        "requestId": "meet-'$(date +%s)'",
        "conferenceSolutionKey": {
          "type": "hangoutsMeet"
        }
      }
    }
  }'
```

**Important:** The `conferenceDataVersion=1` query parameter is required to create/modify conference data.

### Create All-Day Event

```bash
curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Company Holiday",
    "start": {
      "date": "2025-01-20"
    },
    "end": {
      "date": "2025-01-21"
    }
  }'
```

### Using the Helper Script

```bash
# Create event with Meet link (default)
python3 resources/gcal_builder.py \
  create --summary "Team Sync" \
  --start "2025-01-15T10:00:00" \
  --end "2025-01-15T11:00:00" \
  --attendees "brandon@databricks.com,bkvarda@squareup.com" \
  --description "Weekly team synchronization meeting"

# Create without Meet link
python3 resources/gcal_builder.py \
  create --summary "Lunch" \
  --start "2025-01-15T12:00:00" \
  --end "2025-01-15T13:00:00" \
  --no-meet
```

## Managing Attendees

### Add Attendees to Existing Event

First get the event, then update with new attendees:

```bash
# Get current event
EVENT=$(curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng")

# Update with additional attendees
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "attendees": [
      {"email": "existing@example.com"},
      {"email": "new-attendee@example.com"}
    ]
  }'
```

### Remove Attendees

Update the event with the attendee list excluding the person to remove:

```bash
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "attendees": [
      {"email": "keep-this-person@example.com"}
    ]
  }'
```

### Using Helper Script for Attendees

```bash
# Add attendees
python3 gcal_builder.py add-attendees --event-id "EVENT_ID" \
  --attendees "new1@example.com,new2@example.com"

# Remove attendees
python3 gcal_builder.py remove-attendees --event-id "EVENT_ID" \
  --attendees "remove@example.com"
```

### sendUpdates Parameter Options

- `all` - Send notifications to all attendees
- `externalOnly` - Send notifications only to non-Google Calendar users
- `none` - Don't send notifications

## Searching and Reading Events

### List Upcoming Events

```bash
# List next 10 events
curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=10&orderBy=startTime&singleEvents=true&timeMin=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Search Events by Query

```bash
# Search by text (searches summary, description, location, attendees)
curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?q=team+meeting&maxResults=10&singleEvents=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Get Events in Date Range

```bash
# Events between two dates
TIME_MIN="2025-01-01T00:00:00Z"
TIME_MAX="2025-01-31T23:59:59Z"

curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${TIME_MIN}&timeMax=${TIME_MAX}&singleEvents=true&orderBy=startTime" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Get Single Event

```bash
curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Using Helper Script for Search

```bash
# List upcoming events
python3 gcal_builder.py list --max-results 10

# Search events
python3 gcal_builder.py search --query "team meeting"

# Events in date range
python3 gcal_builder.py list --start "2025-01-01" --end "2025-01-31"

# Get specific event
python3 gcal_builder.py get --event-id "EVENT_ID"
```

## Finding Available Meeting Times

Use the FreeBusy API to find times when all (or most) attendees are available. This is essential for scheduling meetings with multiple participants.

### CRITICAL: Always Validate Date Ranges First

**Before scheduling meetings, ALWAYS verify that your date range corresponds to the correct days of the week.** Date/day-of-week mismatches are a common source of scheduling errors (e.g., thinking Friday is Jan 31 when it's actually Saturday).

```bash
# ALWAYS run this first to verify dates
python3 resources/gcal_builder.py validate-dates --start "2025-01-27" --end "2025-01-31"
```

Example output:
```json
{
  "is_valid": true,
  "start": "2025-01-27",
  "end": "2025-01-31",
  "total_days": 5,
  "days": [
    {"date": "2025-01-27", "day_of_week": "Monday", "is_weekend": false},
    {"date": "2025-01-28", "day_of_week": "Tuesday", "is_weekend": false},
    {"date": "2025-01-29", "day_of_week": "Wednesday", "is_weekend": false},
    {"date": "2025-01-30", "day_of_week": "Thursday", "is_weekend": false},
    {"date": "2025-01-31", "day_of_week": "Friday", "is_weekend": false}
  ],
  "warnings": null
}
```

If weekend days are included, you'll see a warning:
```json
{
  "warnings": ["Date range includes weekend days: Saturday 01/31, Sunday 02/01"]
}
```

**The `find-availability` command also includes date validation in its output** to help catch errors before they cause problems.

### Query Free/Busy Information

```bash
TOKEN=$(gcloud auth application-default print-access-token)

# Query free/busy for multiple people over a date range
curl -s -X POST "https://www.googleapis.com/calendar/v3/freeBusy" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "timeMin": "2025-01-20T00:00:00-08:00",
    "timeMax": "2025-01-24T23:59:59-08:00",
    "timeZone": "America/Los_Angeles",
    "items": [
      {"id": "person1@databricks.com"},
      {"id": "person2@databricks.com"},
      {"id": "person3@databricks.com"}
    ]
  }'
```

### FreeBusy Response Format

The response contains busy periods for each calendar:

```json
{
  "kind": "calendar#freeBusy",
  "timeMin": "2025-01-20T08:00:00.000Z",
  "timeMax": "2025-01-25T07:59:59.000Z",
  "calendars": {
    "person1@databricks.com": {
      "busy": [
        {"start": "2025-01-20T17:00:00Z", "end": "2025-01-20T18:00:00Z"},
        {"start": "2025-01-21T15:00:00Z", "end": "2025-01-21T16:00:00Z"}
      ]
    },
    "person2@databricks.com": {
      "busy": [
        {"start": "2025-01-20T18:00:00Z", "end": "2025-01-20T19:00:00Z"}
      ]
    }
  }
}
```

### Using Helper Script to Find Availability

The helper script can automatically find optimal meeting slots:

```bash
# Find 30-minute slots where everyone is available
python3 resources/gcal_builder.py find-availability \
  --attendees "person1@databricks.com,person2@databricks.com,person3@databricks.com" \
  --start "2025-01-20T00:00:00" \
  --end "2025-01-24T23:59:59" \
  --duration 30

# Find 1-hour slots during specific working hours
python3 resources/gcal_builder.py find-availability \
  --attendees "team-lead@databricks.com,engineer@databricks.com" \
  --start "2025-01-20T00:00:00" \
  --end "2025-01-24T23:59:59" \
  --duration 60 \
  --working-hours-start 9 \
  --working-hours-end 17

# Raw free/busy query
python3 resources/gcal_builder.py freebusy \
  --attendees "person1@databricks.com,person2@databricks.com" \
  --start "2025-01-20T00:00:00" \
  --end "2025-01-24T23:59:59"
```

### Find-Availability Response Format

The helper returns organized results with **date validation included**:

```json
{
  "query": {
    "attendees": ["person1@databricks.com", "person2@databricks.com"],
    "time_range": {"start": "2025-01-20T00:00:00", "end": "2025-01-24T23:59:59"},
    "duration_minutes": 30,
    "working_hours": "9:00-17:00",
    "timezone": "America/Los_Angeles"
  },
  "date_validation": {
    "is_valid": true,
    "start": "2025-01-20",
    "end": "2025-01-24",
    "total_days": 5,
    "days": [
      {"date": "2025-01-20", "day_of_week": "Monday", "is_weekend": false},
      {"date": "2025-01-21", "day_of_week": "Tuesday", "is_weekend": false},
      {"date": "2025-01-22", "day_of_week": "Wednesday", "is_weekend": false},
      {"date": "2025-01-23", "day_of_week": "Thursday", "is_weekend": false},
      {"date": "2025-01-24", "day_of_week": "Friday", "is_weekend": false}
    ],
    "warnings": null
  },
  "all_available": [
    {
      "start": "2025-01-20T09:00:00-08:00",
      "end": "2025-01-20T09:30:00-08:00",
      "day": "Mon 1/20",
      "time": "9:00am-9:30am",
      "available": ["person1@databricks.com", "person2@databricks.com"],
      "busy": [],
      "available_count": 2,
      "total_count": 2
    }
  ],
  "some_available": [
    {
      "start": "2025-01-21T14:00:00-08:00",
      "end": "2025-01-21T14:30:00-08:00",
      "day": "Tue 1/21",
      "time": "2:00pm-2:30pm",
      "available": ["person1@databricks.com"],
      "busy": ["person2@databricks.com"],
      "available_count": 1,
      "total_count": 2
    }
  ],
  "summary": {
    "total_attendees": 2,
    "slots_all_available": 15,
    "slots_some_available": 8
  }
}
```

**Key improvements:**
- `date_validation` section shows all days in the range with their day of week
- `day` field shows human-readable day (e.g., "Mon 1/20")
- `time` field shows human-readable time (e.g., "9:00am-9:30am")
- Weekend days are automatically skipped in availability search
- Warnings alert you if weekend days are in your date range

### FreeBusy Limitations

- **Maximum 50 calendars** per query (`calendarExpansionMax`)
- **Maximum 100 members** per group expansion (`groupExpansionMax`)
- Requires read access to calendars (may show errors for external users)
- Only returns busy periods, not event details (privacy protection)

### Common Errors

| Error | Meaning |
|-------|---------|
| `notFound` | Calendar doesn't exist or you don't have access |
| `groupTooBig` | Group has too many members for a single query |
| `tooManyCalendarsRequested` | Exceeded 50 calendar limit |

### Workflow: Find Time and Schedule Meeting

```bash
# 1. Find available slots
AVAILABILITY=$(python3 resources/gcal_builder.py find-availability \
  --attendees "brandon@databricks.com,colleague@databricks.com" \
  --start "2025-01-20T00:00:00" \
  --end "2025-01-24T23:59:59" \
  --duration 30)

# 2. Review the all_available slots
echo "$AVAILABILITY" | jq '.all_available[:5]'

# 3. Create meeting at the best slot
python3 resources/gcal_builder.py create \
  --summary "Team Sync" \
  --start "2025-01-20T09:00:00" \
  --end "2025-01-20T09:30:00" \
  --attendees "brandon@databricks.com,colleague@databricks.com" \
  --description "Scheduled at a time when everyone is available"
```

## Attachments and Documents

### Event Response with Attachments

Events can have attachments in the `attachments` field:

```json
{
  "attachments": [
    {
      "fileUrl": "https://drive.google.com/open?id=FILE_ID",
      "title": "Meeting Notes",
      "mimeType": "application/vnd.google-apps.document",
      "iconLink": "https://drive-thirdparty.googleusercontent.com/16/type/application/vnd.google-apps.document",
      "fileId": "FILE_ID"
    }
  ]
}
```

### Create Event with Attachment

```bash
curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events?supportsAttachments=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Planning Meeting",
    "start": {"dateTime": "2025-01-15T14:00:00-08:00", "timeZone": "America/Los_Angeles"},
    "end": {"dateTime": "2025-01-15T15:00:00-08:00", "timeZone": "America/Los_Angeles"},
    "attachments": [
      {
        "fileUrl": "https://docs.google.com/document/d/DOC_ID/edit",
        "title": "Meeting Agenda"
      }
    ]
  }'
```

### Add Attachment to Existing Event

```bash
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?supportsAttachments=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "attachments": [
      {
        "fileUrl": "https://docs.google.com/document/d/DOC_ID/edit",
        "title": "Running Notes"
      }
    ]
  }'
```

### Using Helper for Attachments

```bash
# Create event with attachment
python3 gcal_builder.py create --summary "Planning" \
  --start "2025-01-15T14:00:00" --end "2025-01-15T15:00:00" \
  --attach-doc "DOC_ID" --attach-title "Meeting Notes"

# Add attachment to existing event
python3 gcal_builder.py attach --event-id "EVENT_ID" \
  --doc-id "DOC_ID" --title "Running Notes"

# List attachments on an event
python3 gcal_builder.py get --event-id "EVENT_ID" --show-attachments
```

### Creating a Running Notes Document

```bash
# Create a Google Doc for meeting notes
python3 ../google-docs/resources/gdocs_builder.py \
  create --title "Meeting Notes - Team Sync 2025-01-15"

# Then attach it to the calendar event
python3 gcal_builder.py attach --event-id "EVENT_ID" \
  --doc-id "NEW_DOC_ID" --title "Running Notes"
```

## Recurring Events (Cadence)

### Recurrence Rule Format (RRULE)

Google Calendar uses iCalendar RRULE format:

```
RRULE:FREQ=<frequency>;[INTERVAL=<n>];[BYDAY=<days>];[COUNT=<n>|UNTIL=<date>]
```

**Frequencies:**
- `DAILY` - Every day
- `WEEKLY` - Every week
- `MONTHLY` - Every month
- `YEARLY` - Every year

**Examples:**
- `RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR` - Every Mon, Wed, Fri
- `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU` - Every 2 weeks on Tuesday
- `RRULE:FREQ=MONTHLY;BYDAY=1MO` - First Monday of every month
- `RRULE:FREQ=DAILY;COUNT=10` - Daily for 10 occurrences
- `RRULE:FREQ=WEEKLY;UNTIL=20251231T235959Z` - Weekly until end of 2025

### Create Recurring Event

```bash
curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Weekly Team Standup",
    "start": {"dateTime": "2025-01-13T09:00:00-08:00", "timeZone": "America/Los_Angeles"},
    "end": {"dateTime": "2025-01-13T09:30:00-08:00", "timeZone": "America/Los_Angeles"},
    "recurrence": ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"],
    "attendees": [
      {"email": "brandon@databricks.com"},
      {"email": "bkvarda@squareup.com"}
    ],
    "conferenceData": {
      "createRequest": {
        "requestId": "standup-'$(date +%s)'",
        "conferenceSolutionKey": {"type": "hangoutsMeet"}
      }
    }
  }'
```

### Change Recurrence (Cadence)

```bash
# Change from weekly to bi-weekly
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "recurrence": ["RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO"]
  }'
```

### Using Helper for Recurrence

```bash
# Create weekly meeting
python3 gcal_builder.py create --summary "Weekly Sync" \
  --start "2025-01-13T09:00:00" --end "2025-01-13T09:30:00" \
  --recurrence "WEEKLY" --days "MO,WE,FR" \
  --attendees "brandon@databricks.com"

# Create bi-weekly meeting
python3 gcal_builder.py create --summary "Bi-weekly 1:1" \
  --start "2025-01-14T14:00:00" --end "2025-01-14T14:30:00" \
  --recurrence "WEEKLY" --interval 2 --days "TU" \
  --attendees "manager@example.com"

# Change cadence of existing event
python3 gcal_builder.py set-recurrence --event-id "EVENT_ID" \
  --recurrence "WEEKLY" --interval 2 --days "MO"

# Remove recurrence (make single event)
python3 gcal_builder.py set-recurrence --event-id "EVENT_ID" --remove
```

### Common Cadence Patterns

| Pattern | RRULE |
|---------|-------|
| Daily | `RRULE:FREQ=DAILY` |
| Weekly on Monday | `RRULE:FREQ=WEEKLY;BYDAY=MO` |
| Every weekday | `RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR` |
| Bi-weekly | `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO` |
| Monthly on 1st Monday | `RRULE:FREQ=MONTHLY;BYDAY=1MO` |
| Monthly on 15th | `RRULE:FREQ=MONTHLY;BYMONTHDAY=15` |
| Quarterly | `RRULE:FREQ=MONTHLY;INTERVAL=3` |

## Modifying Events

### Update Title and Description

```bash
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Updated Meeting Title",
    "description": "Updated description with <a href=\"https://databricks.com\">embedded link</a>"
  }'
```

### Description with Rich Content

The description field supports HTML for links:

```json
{
  "description": "<b>Agenda:</b>\n<ul>\n<li>Review Q4 results</li>\n<li>Plan Q1 initiatives</li>\n</ul>\n\n<b>Resources:</b>\n<a href=\"https://docs.google.com/document/d/DOC_ID\">Meeting Notes</a>\n<a href=\"https://databricks.com\">Company Website</a>"
}
```

### Update Time

```bash
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "start": {"dateTime": "2025-01-15T11:00:00-08:00", "timeZone": "America/Los_Angeles"},
    "end": {"dateTime": "2025-01-15T12:00:00-08:00", "timeZone": "America/Los_Angeles"}
  }'
```

### Update Location

```bash
curl -s -X PATCH "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "location": "Conference Room A / Google Meet"
  }'
```

### Using Helper for Updates

```bash
# Update title
python3 gcal_builder.py update --event-id "EVENT_ID" --summary "New Title"

# Update description with links
python3 gcal_builder.py update --event-id "EVENT_ID" \
  --description "Check out <a href='https://databricks.com'>Databricks</a>"

# Update time
python3 gcal_builder.py update --event-id "EVENT_ID" \
  --start "2025-01-15T11:00:00" --end "2025-01-15T12:00:00"

# Update multiple fields
python3 gcal_builder.py update --event-id "EVENT_ID" \
  --summary "Team Planning" \
  --description "Quarterly planning session" \
  --location "Main Conference Room"
```

## Delete Events

### Delete Single Event

```bash
curl -s -X DELETE "https://www.googleapis.com/calendar/v3/calendars/primary/events/${EVENT_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Delete Single Instance of Recurring Event

For recurring events, each instance has an ID like `eventId_20250115T170000Z`. Delete that specific instance:

```bash
curl -s -X DELETE "https://www.googleapis.com/calendar/v3/calendars/primary/events/${INSTANCE_ID}?sendUpdates=all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Using Helper

```bash
python3 gcal_builder.py delete --event-id "EVENT_ID"
python3 gcal_builder.py delete --event-id "EVENT_ID" --notify  # Send cancellation emails
```

## Helper Scripts

### gcal_builder.py - Complete Calendar Operations

```bash
# Authentication
python3 gcal_builder.py auth-status

# List events
python3 gcal_builder.py list --max-results 10
python3 gcal_builder.py list --start "2025-01-01" --end "2025-01-31"

# Search events
python3 gcal_builder.py search --query "team meeting"

# Get event details
python3 gcal_builder.py get --event-id "EVENT_ID"
python3 gcal_builder.py get --event-id "EVENT_ID" --show-attachments

# Create event (with Meet by default)
python3 gcal_builder.py create --summary "Team Sync" \
  --start "2025-01-15T10:00:00" --end "2025-01-15T11:00:00" \
  --attendees "brandon@databricks.com,bkvarda@squareup.com" \
  --description "Weekly sync meeting"

# Create without Meet
python3 gcal_builder.py create --summary "Lunch" \
  --start "2025-01-15T12:00:00" --end "2025-01-15T13:00:00" --no-meet

# Create recurring event
python3 gcal_builder.py create --summary "Daily Standup" \
  --start "2025-01-13T09:00:00" --end "2025-01-13T09:15:00" \
  --recurrence "WEEKLY" --days "MO,TU,WE,TH,FR" \
  --attendees "team@example.com"

# Update event
python3 gcal_builder.py update --event-id "EVENT_ID" \
  --summary "New Title" --description "New description"

# Add/remove attendees
python3 gcal_builder.py add-attendees --event-id "EVENT_ID" \
  --attendees "new@example.com"
python3 gcal_builder.py remove-attendees --event-id "EVENT_ID" \
  --attendees "remove@example.com"

# Change recurrence
python3 gcal_builder.py set-recurrence --event-id "EVENT_ID" \
  --recurrence "WEEKLY" --interval 2

# Attach document
python3 gcal_builder.py attach --event-id "EVENT_ID" \
  --doc-id "DOC_ID" --title "Meeting Notes"

# Delete event
python3 gcal_builder.py delete --event-id "EVENT_ID"

# Find available meeting times
python3 gcal_builder.py find-availability \
  --attendees "person1@example.com,person2@example.com" \
  --start "2025-01-20T00:00:00" --end "2025-01-24T23:59:59" \
  --duration 30

# Raw free/busy query
python3 gcal_builder.py freebusy \
  --attendees "person1@example.com,person2@example.com" \
  --start "2025-01-20T00:00:00" --end "2025-01-24T23:59:59"
```

### gcal_auth.py - Authentication Management

```bash
python3 gcal_auth.py status    # Check auth status
python3 gcal_auth.py login     # Login with required scopes
python3 gcal_auth.py token     # Get access token
python3 gcal_auth.py validate  # Validate current token
```

### Date Validation (CRITICAL - Use Before Scheduling)

```bash
# Validate date range and see days of week
python3 gcal_builder.py validate-dates --start "2025-01-27" --end "2025-01-31"

# Example output shows each day with its day of week:
# {
#   "days": [
#     {"date": "2025-01-27", "day_of_week": "Monday"},
#     {"date": "2025-01-28", "day_of_week": "Tuesday"},
#     ...
#   ],
#   "warnings": ["Date range includes weekend days: Saturday 02/01"]
# }
```

**Always validate dates before scheduling** to avoid errors like scheduling meetings on weekends or using incorrect date ranges.

## Best Practices

1. **ALWAYS validate date ranges first** using `validate-dates` command before scheduling meetings - this prevents day-of-week errors (e.g., thinking Friday is Jan 31 when it's Saturday)
2. **Always use `conferenceDataVersion=1`** when creating/updating events with Meet links
3. **Use `sendUpdates=all`** when modifying events with attendees to send notifications
4. **Use `supportsAttachments=true`** when working with file attachments
5. **Set timezone explicitly** to avoid confusion with event times
6. **Use `singleEvents=true`** when listing to expand recurring events into instances
7. **Generate unique `requestId`** for conference creation to avoid duplicates
8. **PATCH instead of PUT** for partial updates to avoid overwriting fields

## Example: Create Complete Meeting with Notes

```bash
#!/bin/bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT="gcp-sandbox-field-eng"

# 1. Create meeting notes document
DOC_ID=$(python3 ../google-docs/resources/gdocs_builder.py \
  create --title "Team Sync Notes - $(date +%Y-%m-%d)" | jq -r '.documentId')

echo "Created notes document: $DOC_ID"

# 2. Create calendar event with Meet link and attachment
EVENT=$(curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&supportsAttachments=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Team Sync",
    "description": "<b>Agenda:</b>\n<ul>\n<li>Status updates</li>\n<li>Blockers</li>\n<li>Action items</li>\n</ul>",
    "start": {"dateTime": "'$(date -v+1d +%Y-%m-%dT10:00:00)'-08:00", "timeZone": "America/Los_Angeles"},
    "end": {"dateTime": "'$(date -v+1d +%Y-%m-%dT11:00:00)'-08:00", "timeZone": "America/Los_Angeles"},
    "attendees": [
      {"email": "brandon@databricks.com"},
      {"email": "bkvarda@squareup.com"}
    ],
    "conferenceData": {
      "createRequest": {
        "requestId": "sync-'$(date +%s)'",
        "conferenceSolutionKey": {"type": "hangoutsMeet"}
      }
    },
    "attachments": [
      {
        "fileUrl": "https://docs.google.com/document/d/'$DOC_ID'/edit",
        "title": "Meeting Notes"
      }
    ]
  }')

EVENT_ID=$(echo $EVENT | jq -r '.id')
MEET_LINK=$(echo $EVENT | jq -r '.conferenceData.entryPoints[0].uri')

echo "Created event: $EVENT_ID"
echo "Meet link: $MEET_LINK"
echo "Calendar URL: https://calendar.google.com/calendar/event?eid=$(echo -n "${EVENT_ID} primary" | base64)"
```

## Sources

- [Google Calendar API Reference](https://developers.google.com/calendar/api/v3/reference)
- [Events Resource](https://developers.google.com/calendar/api/v3/reference/events)
- [RRULE Specification](https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10)
- [Conference Data](https://developers.google.com/calendar/api/guides/create-events#conferencing)

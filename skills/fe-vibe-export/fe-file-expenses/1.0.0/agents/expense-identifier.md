# Expense Identifier Agent

Specialized agent for identifying potential expenses from Google Calendar AND potential receipt files from ~/Downloads.

## Model

**Recommended: Sonnet** - This agent needs to intelligently identify travel patterns, external meetings, and potential receipt files.

## Purpose

This agent identifies potential expenses by:
1. **Scanning Google Calendar** for travel events and external meetings
2. **Scanning ~/Downloads** for potential receipt files (images/PDFs from last 7 days)

The goal is to find:
- Calendar events that likely have associated expenses
- Files that could be receipts for processing

## Tools Required

- Bash (for running Calendar helper and listing files)
- Glob (for finding files in ~/Downloads)
- Google Calendar skill

## CRITICAL RULES - READ THESE FIRST

### Rule 1: SCAN BOTH CALENDAR AND DOWNLOADS
- Search Google Calendar for travel and external meetings
- List potential receipt files from ~/Downloads (last 7 days)
- Return both lists for further processing

### Rule 2: DO NOT READ FILE CONTENTS
- List files that COULD be receipts based on extension and date
- DO NOT read or analyze the actual file contents
- File analysis will be done by separate receipt-analyzer agents

### Rule 3: FAST EXECUTION
- Complete in under 60 seconds
- One calendar API call
- One file listing operation

### Rule 4: CAPTURE ATTENDEES FOR EXTERNAL MEETINGS
- For events with external attendees, extract attendee info
- This will be used to populate expense line item attendees later

## Input Parameters

```yaml
cutoff_date: YYYY-MM-DD    # Start of expense period
end_date: YYYY-MM-DD       # End of expense period (usually today)
```

## Workflow

### Step 1: List Potential Receipt Files from ~/Downloads

Find image and PDF files from the last 7 days:

```bash
find ~/Downloads -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.pdf" -o -name "*.heic" \) -mtime -7 2>/dev/null | head -50
```

For each file found, record:
- Full path
- Filename
- File extension
- Any hints from filename (vendor name, date, amount)

### Step 2: Authenticate Google Calendar

```bash
# Check if auth is working
python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/*/skills/google-calendar/resources/gcal_builder.py list \
  --start "$(date -v-1d +%Y/%m/%d)" \
  --end "$(date +%Y/%m/%d)" \
  --max-results 1
```

If auth fails, report "Please authenticate with Google Calendar using /google-auth" and continue with file results only.

### Step 3: List Calendar Events in Date Range

```bash
python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/*/skills/google-calendar/resources/gcal_builder.py list \
  --start "<cutoff_date formatted as YYYY/MM/DD>" \
  --end "<end_date formatted as YYYY/MM/DD>" \
  --max-results 200
```

### Step 4: Analyze Events for Expense Indicators

For each event, check for:

**Travel Indicators:**
| Pattern | Expense Types |
|---------|--------------|
| "flight", "SFO", "JFK", airline names | AIRFARE, AIRWIFI, RIDESHARE |
| "hotel", hotel chain names | HOTEL |
| Multi-day out-of-city events | HOTEL, RIDESHARE, BUSINESSMEAL |
| "airport", "terminal" | RIDESHARE, PARKING |

**External Meeting Indicators:**
| Pattern | Expense Types |
|---------|--------------|
| "dinner", "lunch" + external attendees | BUSINESSMEALEXT |
| "coffee", "meeting" + external attendees | BUSINESSMEAL |
| External attendees (non-@databricks.com) | Potential meal expense |

### Step 5: Return Results

```yaml
date_range:
  cutoff: YYYY-MM-DD
  end: YYYY-MM-DD

# Potential receipt files from ~/Downloads (DO NOT READ CONTENTS)
potential_receipt_files:
  - path: /Users/user/Downloads/verizon_jan_2026.pdf
    filename: verizon_jan_2026.pdf
    extension: pdf
    hints:
      possible_vendor: Verizon
      possible_date: January 2026
  - path: /Users/user/Downloads/IMG_1234.jpg
    filename: IMG_1234.jpg
    extension: jpg
    hints: {}
  - path: /Users/user/Downloads/receipt_uber.png
    filename: receipt_uber.png
    extension: png
    hints:
      possible_vendor: Uber

# Travel events that likely have expenses
travel_events:
  - event_title: "SFO -> NYC"
    dates: ["2026-01-10", "2026-01-12"]
    location: "New York City"
    potential_expenses:
      - type: AIRFARE
        notes: "Round-trip flight"
      - type: AIRWIFI
        notes: "In-flight WiFi if purchased"
      - type: RIDESHARE
        notes: "Airport transfers"
      - type: HOTEL
        notes: "2 nights accommodation"
      - type: BUSINESSMEAL
        notes: "Meals while traveling"

# External meetings that may have meal expenses
external_meetings:
  - event_title: "Q1 Planning Dinner - Acme Corp"
    date: 2026-01-15
    time: "6:00 PM"
    location: "Blue Bottle Coffee, San Francisco"
    internal_attendees:
      - name: Brandon Kvarda
        email: brandon.kvarda@databricks.com
    external_attendees:
      - name: Jane Doe
        email: jane.doe@acme.com
        company: Acme
    potential_expense:
      type: BUSINESSMEALEXT
      notes: "External meal with 2 guests from Acme"

# Summary
summary:
  potential_receipt_files_found: 8
  travel_events_found: 2
  external_meetings_found: 5
  total_potential_expenses: 12
```

## Identifying External Attendees

**External attendee** = email NOT ending in @databricks.com

```python
def is_external(email):
    return not email.endswith('@databricks.com')

def get_company(email):
    domain = email.split('@')[1]
    return domain.split('.')[0].title()  # "acme.com" -> "Acme"
```

## Expected Performance

- Total time: < 60 seconds
- API calls: 1-2 (auth check + event list)
- File operations: 1 (find command)
- Files created: 0
- Output: YAML with calendar events AND potential receipt files

## WHAT NOT TO DO

- **DO NOT** read or analyze receipt file contents - just list them
- **DO NOT** search Gmail
- **DO NOT** access Emburse or Chrome DevTools
- **DO NOT** create any files
- **DO NOT** take a long time - this should be fast

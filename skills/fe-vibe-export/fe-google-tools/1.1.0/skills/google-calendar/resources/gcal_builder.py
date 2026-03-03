#!/usr/bin/env python3
"""
Google Calendar Builder - Complete Calendar Operations Helper

Provides high-level operations for Google Calendar:
- Create events with Google Meet links
- Manage attendees
- Search and list events
- Attach documents
- Handle recurring events
- Update event details

Usage:
    python3 gcal_builder.py create --summary "Meeting" --start "2025-01-15T10:00:00" --end "2025-01-15T11:00:00"
    python3 gcal_builder.py list --max-results 10
    python3 gcal_builder.py search --query "team meeting"
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Any
import urllib.parse
from zoneinfo import ZoneInfo


GCLOUD_PATH = os.path.expanduser("~/google-cloud-sdk/bin/gcloud")
QUOTA_PROJECT = "gcp-sandbox-field-eng"
CALENDAR_API_BASE = "https://www.googleapis.com/calendar/v3"
DEFAULT_TIMEZONE = "America/Los_Angeles"


def get_access_token() -> str:
    """Get access token from gcloud."""
    result = subprocess.run(
        [GCLOUD_PATH, "auth", "application-default", "print-access-token"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Failed to get access token. Run: python3 gcal_auth.py login", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def api_request(method: str, endpoint: str, data: Optional[Dict] = None,
                params: Optional[Dict] = None) -> Dict:
    """Make an authenticated API request to Calendar API."""
    token = get_access_token()
    url = f"{CALENDAR_API_BASE}/{endpoint}"

    if params:
        query_string = urllib.parse.urlencode(params)
        url = f"{url}?{query_string}"

    cmd = ["curl", "-s", "-X", method, url,
           "-H", f"Authorization: Bearer {token}",
           "-H", f"x-goog-user-project: {QUOTA_PROJECT}"]

    if data:
        cmd.extend(["-H", "Content-Type: application/json", "-d", json.dumps(data)])

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"API request failed: {result.stderr}", file=sys.stderr)
        return {}

    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        print(f"Failed to parse response: {result.stdout}", file=sys.stderr)
        return {}


def parse_datetime(dt_str: str) -> str:
    """Parse datetime string and return RFC 3339 format."""
    # If already has timezone, return as is
    if '+' in dt_str or 'Z' in dt_str:
        return dt_str

    # Parse and add timezone
    try:
        dt = datetime.fromisoformat(dt_str)
        # Add Pacific timezone offset (simplified - doesn't handle DST)
        return dt.strftime("%Y-%m-%dT%H:%M:%S") + "-08:00"
    except ValueError:
        return dt_str


def build_recurrence_rule(freq: str, interval: int = 1, days: Optional[str] = None,
                          count: Optional[int] = None, until: Optional[str] = None) -> str:
    """Build RRULE string from parameters."""
    parts = [f"RRULE:FREQ={freq.upper()}"]

    if interval > 1:
        parts.append(f"INTERVAL={interval}")

    if days:
        parts.append(f"BYDAY={days.upper()}")

    if count:
        parts.append(f"COUNT={count}")
    elif until:
        parts.append(f"UNTIL={until.replace('-', '').replace(':', '')}Z")

    return ";".join(parts)


def list_events(max_results: int = 10, start_date: Optional[str] = None,
                end_date: Optional[str] = None) -> List[Dict]:
    """List calendar events."""
    params = {
        "maxResults": max_results,
        "singleEvents": "true",
        "orderBy": "startTime"
    }

    if start_date:
        params["timeMin"] = parse_datetime(start_date + "T00:00:00")
    else:
        params["timeMin"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    if end_date:
        params["timeMax"] = parse_datetime(end_date + "T23:59:59")

    result = api_request("GET", "calendars/primary/events", params=params)
    events = result.get("items", [])

    return [{
        "id": e.get("id"),
        "summary": e.get("summary", "(No title)"),
        "start": e.get("start", {}).get("dateTime", e.get("start", {}).get("date")),
        "end": e.get("end", {}).get("dateTime", e.get("end", {}).get("date")),
        "attendees": [a.get("email") for a in e.get("attendees", [])],
        "meetLink": e.get("conferenceData", {}).get("entryPoints", [{}])[0].get("uri") if e.get("conferenceData") else None,
        "htmlLink": e.get("htmlLink"),
        "recurrence": e.get("recurrence"),
        "attachments": e.get("attachments", [])
    } for e in events]


def search_events(query: str, max_results: int = 10) -> List[Dict]:
    """Search for events matching query."""
    params = {
        "q": query,
        "maxResults": max_results,
        "singleEvents": "true",
        "orderBy": "startTime",
        "timeMin": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    }

    result = api_request("GET", "calendars/primary/events", params=params)
    events = result.get("items", [])

    return [{
        "id": e.get("id"),
        "summary": e.get("summary", "(No title)"),
        "start": e.get("start", {}).get("dateTime", e.get("start", {}).get("date")),
        "end": e.get("end", {}).get("dateTime", e.get("end", {}).get("date")),
        "description": e.get("description", "")[:100],
        "attendees": [a.get("email") for a in e.get("attendees", [])],
        "htmlLink": e.get("htmlLink")
    } for e in events]


def get_event(event_id: str, show_attachments: bool = False) -> Dict:
    """Get a single event by ID."""
    result = api_request("GET", f"calendars/primary/events/{event_id}")

    event = {
        "id": result.get("id"),
        "summary": result.get("summary"),
        "description": result.get("description"),
        "start": result.get("start"),
        "end": result.get("end"),
        "location": result.get("location"),
        "attendees": result.get("attendees", []),
        "recurrence": result.get("recurrence"),
        "meetLink": None,
        "htmlLink": result.get("htmlLink"),
        "attachments": result.get("attachments", [])
    }

    if result.get("conferenceData"):
        entry_points = result["conferenceData"].get("entryPoints", [])
        for ep in entry_points:
            if ep.get("entryPointType") == "video":
                event["meetLink"] = ep.get("uri")
                break

    return event


def create_event(summary: str, start: str, end: str,
                 description: Optional[str] = None,
                 attendees: Optional[List[str]] = None,
                 location: Optional[str] = None,
                 add_meet: bool = True,
                 recurrence: Optional[str] = None,
                 interval: int = 1,
                 days: Optional[str] = None,
                 count: Optional[int] = None,
                 attach_doc_id: Optional[str] = None,
                 attach_title: Optional[str] = None) -> Dict:
    """Create a calendar event."""
    event_data = {
        "summary": summary,
        "start": {
            "dateTime": parse_datetime(start),
            "timeZone": DEFAULT_TIMEZONE
        },
        "end": {
            "dateTime": parse_datetime(end),
            "timeZone": DEFAULT_TIMEZONE
        }
    }

    if description:
        event_data["description"] = description

    if location:
        event_data["location"] = location

    if attendees:
        event_data["attendees"] = [{"email": email.strip()} for email in attendees]

    if add_meet:
        event_data["conferenceData"] = {
            "createRequest": {
                "requestId": f"meet-{int(time.time())}",
                "conferenceSolutionKey": {"type": "hangoutsMeet"}
            }
        }

    if recurrence:
        rrule = build_recurrence_rule(recurrence, interval, days, count)
        event_data["recurrence"] = [rrule]

    if attach_doc_id:
        event_data["attachments"] = [{
            "fileUrl": f"https://docs.google.com/document/d/{attach_doc_id}/edit",
            "title": attach_title or "Document"
        }]

    params = {}
    if add_meet:
        params["conferenceDataVersion"] = "1"
    if attach_doc_id:
        params["supportsAttachments"] = "true"

    result = api_request("POST", "calendars/primary/events", event_data, params)

    return {
        "id": result.get("id"),
        "summary": result.get("summary"),
        "htmlLink": result.get("htmlLink"),
        "meetLink": result.get("conferenceData", {}).get("entryPoints", [{}])[0].get("uri") if result.get("conferenceData") else None,
        "start": result.get("start"),
        "end": result.get("end")
    }


def update_event(event_id: str, summary: Optional[str] = None,
                 description: Optional[str] = None,
                 start: Optional[str] = None,
                 end: Optional[str] = None,
                 location: Optional[str] = None,
                 send_updates: str = "all") -> Dict:
    """Update an existing event."""
    update_data = {}

    if summary:
        update_data["summary"] = summary
    if description:
        update_data["description"] = description
    if location:
        update_data["location"] = location
    if start:
        update_data["start"] = {
            "dateTime": parse_datetime(start),
            "timeZone": DEFAULT_TIMEZONE
        }
    if end:
        update_data["end"] = {
            "dateTime": parse_datetime(end),
            "timeZone": DEFAULT_TIMEZONE
        }

    params = {"sendUpdates": send_updates}
    result = api_request("PATCH", f"calendars/primary/events/{event_id}",
                        update_data, params)

    return {
        "id": result.get("id"),
        "summary": result.get("summary"),
        "htmlLink": result.get("htmlLink"),
        "updated": True
    }


def add_attendees(event_id: str, attendees: List[str], send_updates: str = "all") -> Dict:
    """Add attendees to an existing event."""
    # Get current event
    current = api_request("GET", f"calendars/primary/events/{event_id}")
    current_attendees = current.get("attendees", [])

    # Add new attendees
    existing_emails = {a.get("email") for a in current_attendees}
    for email in attendees:
        email = email.strip()
        if email not in existing_emails:
            current_attendees.append({"email": email})

    # Update event
    params = {"sendUpdates": send_updates}
    result = api_request("PATCH", f"calendars/primary/events/{event_id}",
                        {"attendees": current_attendees}, params)

    return {
        "id": result.get("id"),
        "attendees": [a.get("email") for a in result.get("attendees", [])],
        "updated": True
    }


def remove_attendees(event_id: str, attendees: List[str], send_updates: str = "all") -> Dict:
    """Remove attendees from an existing event."""
    # Get current event
    current = api_request("GET", f"calendars/primary/events/{event_id}")
    current_attendees = current.get("attendees", [])

    # Filter out removed attendees
    remove_set = {email.strip().lower() for email in attendees}
    new_attendees = [a for a in current_attendees
                     if a.get("email", "").lower() not in remove_set]

    # Update event
    params = {"sendUpdates": send_updates}
    result = api_request("PATCH", f"calendars/primary/events/{event_id}",
                        {"attendees": new_attendees}, params)

    return {
        "id": result.get("id"),
        "attendees": [a.get("email") for a in result.get("attendees", [])],
        "updated": True
    }


def set_recurrence(event_id: str, recurrence: Optional[str] = None,
                   interval: int = 1, days: Optional[str] = None,
                   count: Optional[int] = None, remove: bool = False) -> Dict:
    """Set or remove recurrence on an event."""
    if remove:
        update_data = {"recurrence": None}
    else:
        rrule = build_recurrence_rule(recurrence, interval, days, count)
        update_data = {"recurrence": [rrule]}

    result = api_request("PATCH", f"calendars/primary/events/{event_id}", update_data)

    return {
        "id": result.get("id"),
        "recurrence": result.get("recurrence"),
        "updated": True
    }


def attach_document(event_id: str, doc_id: str, title: str = "Document") -> Dict:
    """Attach a Google Doc to an event."""
    # Get current event to preserve existing attachments
    current = api_request("GET", f"calendars/primary/events/{event_id}")
    attachments = current.get("attachments", [])

    # Add new attachment
    attachments.append({
        "fileUrl": f"https://docs.google.com/document/d/{doc_id}/edit",
        "title": title
    })

    params = {"supportsAttachments": "true"}
    result = api_request("PATCH", f"calendars/primary/events/{event_id}",
                        {"attachments": attachments}, params)

    return {
        "id": result.get("id"),
        "attachments": result.get("attachments", []),
        "updated": True
    }


def delete_event(event_id: str, send_updates: str = "all") -> Dict:
    """Delete an event."""
    token = get_access_token()
    url = f"{CALENDAR_API_BASE}/calendars/primary/events/{event_id}?sendUpdates={send_updates}"

    cmd = ["curl", "-s", "-X", "DELETE", url,
           "-H", f"Authorization: Bearer {token}",
           "-H", f"x-goog-user-project: {QUOTA_PROJECT}"]

    subprocess.run(cmd, capture_output=True)
    return {"deleted": True, "event_id": event_id}


def query_freebusy(emails: List[str], time_min: str, time_max: str,
                   timezone: str = DEFAULT_TIMEZONE) -> Dict:
    """Query free/busy information for a list of calendars."""
    data = {
        "timeMin": parse_datetime(time_min),
        "timeMax": parse_datetime(time_max),
        "timeZone": timezone,
        "items": [{"id": email.strip()} for email in emails]
    }

    token = get_access_token()
    url = f"{CALENDAR_API_BASE}/freeBusy"

    cmd = ["curl", "-s", "-X", "POST", url,
           "-H", f"Authorization: Bearer {token}",
           "-H", f"x-goog-user-project: {QUOTA_PROJECT}",
           "-H", "Content-Type: application/json",
           "-d", json.dumps(data)]

    result = subprocess.run(cmd, capture_output=True, text=True)

    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        print(f"Failed to parse response: {result.stdout}", file=sys.stderr)
        return {}


def parse_datetime_with_tz(dt_str: str, tz_name: str = DEFAULT_TIMEZONE) -> datetime:
    """
    Parse a datetime string and ensure it has timezone info.

    Handles various formats:
    - ISO format with timezone offset: 2025-01-20T09:00:00-08:00
    - ISO format with Z: 2025-01-20T17:00:00Z
    - ISO format without timezone: 2025-01-20T09:00:00
    """
    # Handle Z suffix (UTC)
    if dt_str.endswith('Z'):
        dt_str = dt_str[:-1] + '+00:00'

    try:
        dt = datetime.fromisoformat(dt_str)
    except ValueError:
        # Try parsing without timezone and add default
        dt = datetime.fromisoformat(dt_str.split('+')[0].split('-08:00')[0])
        dt = dt.replace(tzinfo=ZoneInfo(tz_name))
        return dt

    # If no timezone info, add the default timezone
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=ZoneInfo(tz_name))

    return dt


def validate_date_range(start_date: str, end_date: str) -> Dict:
    """
    Validate a date range and return information about the days included.

    This helps prevent errors where users specify incorrect date ranges
    (e.g., thinking Friday is Jan 31 when it's actually Jan 30).

    Returns a dict with:
    - is_valid: bool
    - days: list of {date, day_of_week, is_weekend}
    - warnings: any issues detected
    """
    try:
        # Parse dates (handle both date-only and datetime formats)
        start_str = start_date.split('T')[0]
        end_str = end_date.split('T')[0]

        start = datetime.strptime(start_str, "%Y-%m-%d")
        end = datetime.strptime(end_str, "%Y-%m-%d")

        if end < start:
            return {
                "is_valid": False,
                "error": "End date is before start date",
                "start": start_str,
                "end": end_str
            }

        days = []
        current = start
        weekend_days = []

        while current <= end:
            day_name = current.strftime("%A")
            is_weekend = current.weekday() >= 5  # Saturday=5, Sunday=6

            day_info = {
                "date": current.strftime("%Y-%m-%d"),
                "day_of_week": day_name,
                "is_weekend": is_weekend
            }
            days.append(day_info)

            if is_weekend:
                weekend_days.append(f"{day_name} {current.strftime('%m/%d')}")

            current += timedelta(days=1)

        warnings = []
        if weekend_days:
            warnings.append(f"Date range includes weekend days: {', '.join(weekend_days)}")

        return {
            "is_valid": True,
            "start": start_str,
            "end": end_str,
            "total_days": len(days),
            "days": days,
            "warnings": warnings if warnings else None
        }

    except ValueError as e:
        return {
            "is_valid": False,
            "error": f"Invalid date format: {str(e)}"
        }


def find_available_slots(emails: List[str], time_min: str, time_max: str,
                         duration_minutes: int = 30,
                         working_hours_start: int = 9,
                         working_hours_end: int = 17,
                         tz_name: str = DEFAULT_TIMEZONE) -> Dict:
    """
    Find time slots when all (or most) attendees are available.

    Returns slots sorted by number of available attendees (most available first).
    """
    # First, validate the date range and show what days we're searching
    date_validation = validate_date_range(time_min, time_max)

    freebusy = query_freebusy(emails, time_min, time_max, tz_name)

    if not freebusy or "calendars" not in freebusy:
        return {"error": "Failed to query free/busy information", "raw": freebusy}

    # Collect all busy periods per person
    busy_by_person = {}
    errors = {}
    for email in emails:
        email = email.strip()
        cal_info = freebusy.get("calendars", {}).get(email, {})
        if cal_info.get("errors"):
            errors[email] = cal_info["errors"]
            continue
        busy_by_person[email] = cal_info.get("busy", [])

    # Get timezone for consistent handling
    tz = ZoneInfo(tz_name)

    # Parse time range with proper timezone handling
    start_dt = parse_datetime_with_tz(time_min, tz_name)
    end_dt = parse_datetime_with_tz(time_max, tz_name)

    # Adjust to working hours on the start day
    start_dt = start_dt.replace(hour=working_hours_start, minute=0, second=0, microsecond=0)

    slots = []
    current = start_dt
    slot_duration = timedelta(minutes=duration_minutes)

    while current + slot_duration <= end_dt:
        # Skip weekends
        if current.weekday() >= 5:  # Saturday=5, Sunday=6
            # Move to next day at working_hours_start
            current = (current + timedelta(days=1)).replace(
                hour=working_hours_start, minute=0, second=0, microsecond=0
            )
            continue

        # Check if within working hours
        slot_end_hour = (current + slot_duration).hour
        slot_end_minute = (current + slot_duration).minute

        # If slot would end after working hours, move to next day
        if current.hour >= working_hours_end or (slot_end_hour > working_hours_end) or \
           (slot_end_hour == working_hours_end and slot_end_minute > 0):
            # Move to next day at working_hours_start
            current = (current + timedelta(days=1)).replace(
                hour=working_hours_start, minute=0, second=0, microsecond=0
            )
            continue

        if current.hour >= working_hours_start:
            slot_start_str = current.isoformat()
            slot_end_str = (current + slot_duration).isoformat()

            # Format for display: "Mon 1/20 9:00-10:00"
            day_label = current.strftime("%a %-m/%-d")
            time_label = f"{current.strftime('%-I:%M%p').lower()}-{(current + slot_duration).strftime('%-I:%M%p').lower()}"

            # Check availability for each person
            available = []
            busy = []

            for email, busy_periods in busy_by_person.items():
                is_free = True
                for period in busy_periods:
                    busy_start = parse_datetime_with_tz(period["start"], tz_name)
                    busy_end = parse_datetime_with_tz(period["end"], tz_name)

                    # Check for overlap (both datetimes are now timezone-aware)
                    if not (current >= busy_end or current + slot_duration <= busy_start):
                        is_free = False
                        break

                if is_free:
                    available.append(email)
                else:
                    busy.append(email)

            slots.append({
                "start": slot_start_str,
                "end": slot_end_str,
                "day": day_label,
                "time": time_label,
                "available": available,
                "busy": busy,
                "available_count": len(available),
                "total_count": len(busy_by_person)
            })

        # Move to next slot (30-minute increments for scanning)
        current += timedelta(minutes=30)

    # Sort by most available first, then by date
    slots.sort(key=lambda x: (-x["available_count"], x["start"]))

    # Filter to only slots where at least someone is available
    slots = [s for s in slots if s["available_count"] > 0]

    # Group slots by availability count for easier reading
    all_available = [s for s in slots if s["available_count"] == len(busy_by_person)]
    some_available = [s for s in slots if 0 < s["available_count"] < len(busy_by_person)]

    return {
        "query": {
            "attendees": emails,
            "time_range": {"start": time_min, "end": time_max},
            "duration_minutes": duration_minutes,
            "working_hours": f"{working_hours_start}:00-{working_hours_end}:00",
            "timezone": tz_name
        },
        "date_validation": date_validation,
        "all_available": all_available[:10],  # Top 10 slots where everyone is free
        "some_available": some_available[:10],  # Top 10 partial availability
        "summary": {
            "total_attendees": len(busy_by_person),
            "slots_all_available": len(all_available),
            "slots_some_available": len(some_available)
        },
        "errors": errors if errors else None
    }


def main():
    parser = argparse.ArgumentParser(
        description="Google Calendar operations helper",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = parser.add_subparsers(dest="command")

    # List events
    list_parser = subparsers.add_parser("list", help="List upcoming events")
    list_parser.add_argument("--max-results", "-n", type=int, default=10)
    list_parser.add_argument("--start", help="Start date (YYYY-MM-DD)")
    list_parser.add_argument("--end", help="End date (YYYY-MM-DD)")

    # Search events
    search_parser = subparsers.add_parser("search", help="Search events")
    search_parser.add_argument("--query", "-q", required=True, help="Search query")
    search_parser.add_argument("--max-results", "-n", type=int, default=10)

    # Get event
    get_parser = subparsers.add_parser("get", help="Get event details")
    get_parser.add_argument("--event-id", required=True, help="Event ID")
    get_parser.add_argument("--show-attachments", action="store_true")

    # Create event
    create_parser = subparsers.add_parser("create", help="Create event")
    create_parser.add_argument("--summary", required=True, help="Event title")
    create_parser.add_argument("--start", required=True, help="Start time (ISO format)")
    create_parser.add_argument("--end", required=True, help="End time (ISO format)")
    create_parser.add_argument("--description", help="Event description")
    create_parser.add_argument("--attendees", help="Comma-separated emails")
    create_parser.add_argument("--location", help="Event location")
    create_parser.add_argument("--no-meet", action="store_true", help="Don't add Meet link")
    create_parser.add_argument("--recurrence", help="Recurrence: DAILY, WEEKLY, MONTHLY, YEARLY")
    create_parser.add_argument("--interval", type=int, default=1, help="Recurrence interval")
    create_parser.add_argument("--days", help="Days for WEEKLY (e.g., MO,WE,FR)")
    create_parser.add_argument("--count", type=int, help="Number of occurrences")
    create_parser.add_argument("--attach-doc", help="Google Doc ID to attach")
    create_parser.add_argument("--attach-title", help="Title for attachment")

    # Update event
    update_parser = subparsers.add_parser("update", help="Update event")
    update_parser.add_argument("--event-id", required=True, help="Event ID")
    update_parser.add_argument("--summary", help="New title")
    update_parser.add_argument("--description", help="New description")
    update_parser.add_argument("--start", help="New start time")
    update_parser.add_argument("--end", help="New end time")
    update_parser.add_argument("--location", help="New location")
    update_parser.add_argument("--no-notify", action="store_true", help="Don't notify attendees")

    # Add attendees
    add_att_parser = subparsers.add_parser("add-attendees", help="Add attendees")
    add_att_parser.add_argument("--event-id", required=True)
    add_att_parser.add_argument("--attendees", required=True, help="Comma-separated emails")
    add_att_parser.add_argument("--no-notify", action="store_true")

    # Remove attendees
    rm_att_parser = subparsers.add_parser("remove-attendees", help="Remove attendees")
    rm_att_parser.add_argument("--event-id", required=True)
    rm_att_parser.add_argument("--attendees", required=True, help="Comma-separated emails")
    rm_att_parser.add_argument("--no-notify", action="store_true")

    # Set recurrence
    recur_parser = subparsers.add_parser("set-recurrence", help="Set/change recurrence")
    recur_parser.add_argument("--event-id", required=True)
    recur_parser.add_argument("--recurrence", help="DAILY, WEEKLY, MONTHLY, YEARLY")
    recur_parser.add_argument("--interval", type=int, default=1)
    recur_parser.add_argument("--days", help="Days for WEEKLY")
    recur_parser.add_argument("--count", type=int)
    recur_parser.add_argument("--remove", action="store_true", help="Remove recurrence")

    # Attach document
    attach_parser = subparsers.add_parser("attach", help="Attach document")
    attach_parser.add_argument("--event-id", required=True)
    attach_parser.add_argument("--doc-id", required=True, help="Google Doc ID")
    attach_parser.add_argument("--title", default="Document", help="Attachment title")

    # Delete event
    delete_parser = subparsers.add_parser("delete", help="Delete event")
    delete_parser.add_argument("--event-id", required=True)
    delete_parser.add_argument("--notify", action="store_true", help="Send cancellation emails")

    # FreeBusy query
    freebusy_parser = subparsers.add_parser("freebusy", help="Query free/busy for calendars")
    freebusy_parser.add_argument("--attendees", required=True, help="Comma-separated emails")
    freebusy_parser.add_argument("--start", required=True, help="Start time (ISO format)")
    freebusy_parser.add_argument("--end", required=True, help="End time (ISO format)")

    # Find availability
    avail_parser = subparsers.add_parser("find-availability", help="Find times when attendees are available")
    avail_parser.add_argument("--attendees", required=True, help="Comma-separated emails")
    avail_parser.add_argument("--start", required=True, help="Start date/time (ISO format)")
    avail_parser.add_argument("--end", required=True, help="End date/time (ISO format)")
    avail_parser.add_argument("--duration", type=int, default=30, help="Meeting duration in minutes (default: 30)")
    avail_parser.add_argument("--working-hours-start", type=int, default=9, help="Working hours start (default: 9)")
    avail_parser.add_argument("--working-hours-end", type=int, default=17, help="Working hours end (default: 17)")

    # Auth status
    subparsers.add_parser("auth-status", help="Check authentication status")

    # Validate dates
    validate_parser = subparsers.add_parser("validate-dates", help="Validate date range and show days of week")
    validate_parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD or ISO format)")
    validate_parser.add_argument("--end", required=True, help="End date (YYYY-MM-DD or ISO format)")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    result = None

    if args.command == "list":
        result = list_events(args.max_results, args.start, args.end)

    elif args.command == "search":
        result = search_events(args.query, args.max_results)

    elif args.command == "get":
        result = get_event(args.event_id, args.show_attachments)

    elif args.command == "create":
        attendees = args.attendees.split(",") if args.attendees else None
        result = create_event(
            args.summary, args.start, args.end,
            description=args.description,
            attendees=attendees,
            location=args.location,
            add_meet=not args.no_meet,
            recurrence=args.recurrence,
            interval=args.interval,
            days=args.days,
            count=args.count,
            attach_doc_id=args.attach_doc,
            attach_title=args.attach_title
        )

    elif args.command == "update":
        send_updates = "none" if args.no_notify else "all"
        result = update_event(
            args.event_id,
            summary=args.summary,
            description=args.description,
            start=args.start,
            end=args.end,
            location=args.location,
            send_updates=send_updates
        )

    elif args.command == "add-attendees":
        send_updates = "none" if args.no_notify else "all"
        attendees = [e.strip() for e in args.attendees.split(",")]
        result = add_attendees(args.event_id, attendees, send_updates)

    elif args.command == "remove-attendees":
        send_updates = "none" if args.no_notify else "all"
        attendees = [e.strip() for e in args.attendees.split(",")]
        result = remove_attendees(args.event_id, attendees, send_updates)

    elif args.command == "set-recurrence":
        result = set_recurrence(
            args.event_id,
            recurrence=args.recurrence,
            interval=args.interval,
            days=args.days,
            count=args.count,
            remove=args.remove
        )

    elif args.command == "attach":
        result = attach_document(args.event_id, args.doc_id, args.title)

    elif args.command == "delete":
        send_updates = "all" if args.notify else "none"
        result = delete_event(args.event_id, send_updates)

    elif args.command == "freebusy":
        attendees = [e.strip() for e in args.attendees.split(",")]
        result = query_freebusy(attendees, args.start, args.end)

    elif args.command == "find-availability":
        attendees = [e.strip() for e in args.attendees.split(",")]
        result = find_available_slots(
            attendees, args.start, args.end,
            duration_minutes=args.duration,
            working_hours_start=args.working_hours_start,
            working_hours_end=args.working_hours_end
        )

    elif args.command == "auth-status":
        import gcal_auth
        gcal_auth.print_status()
        sys.exit(0)

    elif args.command == "validate-dates":
        result = validate_date_range(args.start, args.end)

    if result is not None:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

---
name: fe-todo-list
description: Manage your FE TODO list - discover action items from Slack, email, Drive, and meetings, then sync to a Google Sheet
user-invocable: true
---

# FE TODO List Manager

This skill helps Field Engineers discover and track action items across multiple sources:
- Slack DMs and external channels
- Gmail inbox
- Google Drive documents
- Calendar meeting notes

All discovered items are synced to a centralized Google Sheet for easy tracking.

## Quick Start

```
/fe-todo-list              # Full sync: discover + update
/fe-todo-list discover     # Only discover new items (don't update sheet)
/fe-todo-list update       # Only update sheet (use last discovery)
/fe-todo-list status       # Show current TODO stats
/fe-todo-list open         # Open the TODO sheet in browser
```

## Prerequisites

Before using this skill, ensure you have:

1. **Vibe profile configured** - Run `/configure-vibe` if not set up
2. **Google authentication** - Run `/google-auth` if not authenticated
3. **Slack MCP access** - Run `/validate-mcp-access` if Slack isn't working

## How It Works

### Phase 1: Discovery (`fe-todo-discovery` agent)

The discovery agent scans multiple sources for potential action items:

| Source | What It Looks For |
|--------|-------------------|
| **Slack ext channels** | Unanswered customer questions, requests without responses |
| **Slack DMs** | Requests made to you, commitments you made |
| **Gmail** | Emails requiring response (excludes spam, dist lists) |
| **Google Drive** | Recent docs with action items, unchecked checkboxes |
| **Calendar** | Meeting notes with assigned tasks, follow-ups |

Each discovered item includes:
- Task description
- Source and link
- Associated account (if applicable)
- Priority (HIGH/MEDIUM/LOW)
- Due date (if known)
- Confidence level

### Phase 2: Update (`fe-todo-updater` agent)

The updater agent syncs discovered items with your TODO sheet:

1. **Creates sheet if needed** - New users get a pre-formatted sheet
2. **Compares with existing items** - Finds new, updated, and completed tasks
3. **Updates the sheet** - Adds new items, updates existing, moves completed
4. **Tracks low-confidence items** - Puts uncertain items in "Quick Capture" for triage

## Sheet Structure

Your TODO sheet has 4 tabs:

| Tab | Purpose |
|-----|---------|
| **Active Tasks** | Current action items with priority, status, due dates |
| **Blocked** | Items waiting on someone else |
| **Completed** | Finished items (last 7 days) |
| **Quick Capture** | Low-confidence items needing triage |

### Active Tasks Columns

| Column | Description |
|--------|-------------|
| Task | What needs to be done |
| Account | Customer account (if applicable) |
| Source | Where discovered (slack/email/drive/calendar) |
| Priority | HIGH (red), MEDIUM (orange), LOW (green) |
| Due Date | When it's due |
| Status | Not Started, In Progress, Blocked, Done |
| Next Action | Specific next step |
| Links | Source links |
| Notes | Additional context |
| Discovered | When first found |
| Last Updated | Last sync time |

## Usage Examples

### Full Sync (Most Common)

```
/fe-todo-list
```

This runs both discovery and update:
1. Scans all sources for new action items
2. Compares with your current sheet
3. Adds new items, updates existing ones
4. Reports summary of changes

### Discovery Only

```
/fe-todo-list discover
```

Use this to see what action items exist without updating the sheet:
- Useful for preview before making changes
- Good for debugging discovery issues

### Update Only

```
/fe-todo-list update
```

Use cached discovery results to update sheet:
- Faster if you just ran discovery
- Useful if discovery succeeded but update failed

### Check Status

```
/fe-todo-list status
```

Shows:
- Total active tasks
- Items due this week
- Blocked items count
- Last sync time

### Open Sheet

```
/fe-todo-list open
```

Opens your TODO sheet in the default browser.

## Configuration

### Sheet Location

The sheet ID is stored in `~/.vibe/todo`:

```yaml
sheet_id: 1ABC123...
sheet_url: https://docs.google.com/spreadsheets/d/1ABC123.../edit
last_updated: 2026-01-09T10:30:00Z
```

### Custom Sheet

To use an existing sheet:

```bash
echo "sheet_id: YOUR_SHEET_ID" > ~/.vibe/todo
echo "sheet_url: https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit" >> ~/.vibe/todo
```

The sheet must have the expected tab structure (Active Tasks, Blocked, Completed, Quick Capture).

## Workflow Recommendations

### Daily Routine

1. Morning: Run `/fe-todo-list` to sync overnight items
2. Work through Active Tasks tab during the day
3. Update statuses manually as you complete items
4. Evening: Run `/fe-todo-list status` to see remaining items

### Weekly Review

1. Monday: Full sync to start the week
2. Review "Quick Capture" tab and move items to Active or delete
3. Check "Blocked" tab and follow up on blockers
4. Archive completed items older than 7 days

## Troubleshooting

### "No profile found"

Run `/configure-vibe` to set up your profile with accounts and channels.

### "Slack MCP not authenticated"

Run `/validate-mcp-access` and follow the authentication steps.

### "Google auth failed"

Run `/google-auth` to refresh your Google credentials.

### "Sheet not found"

Your sheet may have been deleted. Run `/fe-todo-list` to create a new one, or check `~/.vibe/todo` for the correct sheet ID.

### Discovery finds too many/few items

Adjust your profile's channel list:
- Add important channels you're missing
- Remove noisy channels that create false positives

## Privacy & Data

- All data stays in your Google account (Sheet, Drive)
- Slack/Gmail are only read, never modified
- Discovery results are cached locally in `~/.vibe/`
- No data is sent to external services

## Related Skills

- `/configure-vibe` - Set up your vibe profile
- `/google-auth` - Authenticate with Google
- `/validate-mcp-access` - Check Slack/Glean access
- `/gmail` - Direct Gmail operations
- `/google-sheets-creator` - Create custom sheets

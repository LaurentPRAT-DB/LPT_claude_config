---
name: file-expenses
description: File expense reports with Emburse ChromeRiver - automatically identify, collect receipts, and submit expense reports
---

# File Expenses Skill

Automate expense report filing with Emburse ChromeRiver. This skill orchestrates specialized subagents to build expense profiles, discover receipts, and create expense reports.

## CRITICAL: Mandatory Subagent Delegation

**This skill is an ORCHESTRATOR. The main agent MUST NOT do the work directly.**

### MANDATORY Rules

1. **ALWAYS delegate to subagents** - The main agent orchestrates; subagents do the work
2. **NEVER read receipt images directly** - Use `receipt-analyzer` or `expense-line-item-processor` agents
3. **NEVER analyze historical expenses directly** - Use `historical-profile-builder` agent
4. **RUN PROFILER FIRST** - Then discovery, then receipt analysis

### What the Main Agent SHOULD Do

- Launch subagents using the Task tool
- Aggregate results from subagents
- Present combined findings to user
- Conduct user walkthrough based on findings

### What the Main Agent MUST NOT Do

- Read/analyze receipt images (delegate to subagents)
- Read historical expense reports (delegate to historical-profile-builder)

## Prerequisites

- Chrome DevTools MCP server must be running (verify with `mcp-cli tools chrome-devtools`)
- Google Calendar access (for travel/meeting detection)

## Recovering Chrome DevTools MCP

If the Chrome DevTools MCP server fails or disconnects:

1. **Check status**: Run `/mcp` in Claude Code to see server status
2. **Reconnect**: Run `/mcp` again - it will attempt to reconnect
3. **If still failing**: The user may need to restart Chrome or the MCP server

**In your workflow**: If an MCP call fails with "Server 'chrome-devtools' is not connected", tell the user:
```
The Chrome DevTools MCP server disconnected. Please run /mcp to reconnect, then let me know to continue.
```

## US Expense Policy Rules

| Category | Rule | Limit |
|----------|------|-------|
| FITNESS | Monthly maximum | $250/month |
| INTERNETWIFI | Monthly maximum | $50/month |
| CELLPHONE | Single line only | No family plans |
| All categories | Receipt required | Receipts required |

**Never auto-submit reports** - always leave as draft for user review.

## Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| `historical-profile-builder` | Sonnet | Analyze 6 months expenses - builds vendor-category map |
| `expense-identifier` | Sonnet | Scans calendar AND ~/Downloads for potential receipts |
| `receipt-analyzer` | Haiku | Analyzes ONE file to determine if it's a receipt |
| `expense-line-item-processor` | Sonnet | Processes confirmed receipts into line items |

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      PHASE 1: PROFILE                           │
│  Run historical-profile-builder (wait for completion)           │
│  → Returns: cutoff_date, vendor_category_map, recurring_monthly │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      PHASE 2: DISCOVERY                         │
│  Run expense-identifier                                         │
│  → Scans Google Calendar for travel & external meetings         │
│  → Lists potential receipt files from ~/Downloads (last 7 days) │
│  → Returns: travel_events, external_meetings, potential_files   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PHASE 3: RECEIPT ANALYSIS                     │
│  For each potential file, launch receipt-analyzer (4 at a time) │
│  → Each analyzer reads ONE file and determines if it's a receipt│
│  → Returns: is_receipt, vendor, amount, category for each       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PHASE 4: COMBINE FINDINGS                     │
│  Merge results from profile + discovery + receipt analysis:     │
│  → Confirmed receipts we found                                  │
│  → Calendar events that likely need receipts                    │
│  → Recurring expenses we're probably missing                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 5: USER WALKTHROUGH                    │
│  Present combined findings to user:                             │
│  → "I found these receipts: [list]"                             │
│  → "Based on your calendar, you may be missing: [list]"         │
│  → "Your recurring expenses not found: [list]"                  │
│  → User confirms which to process, provides missing receipts    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 6: PROCESSING                          │
│  For each confirmed receipt, use expense-line-item-processor    │
│  → Creates line items in Emburse                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 7: FINAL REVIEW                        │
│  Present summary and draft link (DO NOT SUBMIT)                 │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Instructions

### Phase 1: Build Historical Profile

**Run the profiler FIRST and wait for completion.**

```yaml
Task (historical-profile-builder):
  subagent_type: fe-file-expenses:historical-profile-builder
  model: sonnet
  prompt: |
    Build expense profile from Emburse. This should be FAST (under 30 seconds).

    DO NOT create any files. Return structured YAML output only.

    Use ONE batch API call to get all data.

    Return:
    - cutoff_date (end date of most recent report)
    - user_info (personId, email)
    - allocation (matterId, matterUniqueId, clientName)
    - vendor_category_map (vendor -> category mapping)
    - recurring_monthly (wifi, cellular, fitness, learning with typical amounts)
    - sporadic_patterns (meals, rideshares, hotels, parking)
    - travel_patterns (travels_frequently, typical_rideshare_vendor)
```

**Wait for this to complete before proceeding.**

### Phase 2: Discovery

**Run expense-identifier to find calendar events AND potential receipt files.**

```yaml
Task (expense-identifier):
  subagent_type: fe-file-expenses:expense-identifier
  model: sonnet
  prompt: |
    Identify potential expenses from Google Calendar AND potential receipt files.

    Date range: <cutoff_date> to today

    1. List potential receipt files from ~/Downloads (images/PDFs from last 7 days)
       - DO NOT read file contents, just list them with path and filename
    2. Search Google Calendar for travel events and external meetings
       - Capture attendee info for external meetings

    Return:
    - potential_receipt_files (list of paths)
    - travel_events (dates, locations, expected expense types)
    - external_meetings (with attendee details)
```

### Phase 3: Receipt Analysis

**For each potential file from Phase 2, launch receipt-analyzer agents.**

**CRITICAL: Launch up to 4 analyzers in parallel to speed up processing.**

```yaml
# Launch 4 at a time in a SINGLE message with multiple Task tool calls
Task 1 (receipt-analyzer):
  subagent_type: fe-file-expenses:receipt-analyzer
  model: haiku
  prompt: |
    Analyze this file to determine if it's a receipt.

    File path: <path_1>

    Vendor category map (for suggestions):
    <vendor_category_map from profile>

    Return: is_receipt (true/false/maybe), vendor, amount, date, suggested_category

Task 2 (receipt-analyzer):
  subagent_type: fe-file-expenses:receipt-analyzer
  model: haiku
  prompt: |
    Analyze this file to determine if it's a receipt.

    File path: <path_2>
    ...

Task 3 (receipt-analyzer):
  ...

Task 4 (receipt-analyzer):
  ...
```

**Wait for all 4 to complete, then launch next batch of 4, until all files analyzed.**

### Phase 4: Combine Findings

After all discovery and analysis is complete, combine the results:

```yaml
combined_findings:
  # Confirmed receipts from ~/Downloads
  confirmed_receipts:
    - path: /Users/user/Downloads/verizon_jan.pdf
      vendor: Verizon
      amount: 80.00
      category: MobSec Mobile
      matches_recurring: true  # Matches recurring cellular from profile

    - path: /Users/user/Downloads/uber_receipt.png
      vendor: Uber
      amount: 45.00
      category: TAXI
      matches_calendar: "NYC Trip Jan 10-12"  # Matches travel event

  # Calendar events that likely need receipts (not yet found)
  calendar_events_missing_receipts:
    - event: "NYC Trip (Jan 10-12)"
      expected_expenses:
        - type: HOTEL
          found: false
        - type: AIRWIFI
          found: false
        - type: RIDESHARE
          found: true  # Found Uber receipt above

    - event: "Customer Dinner - Acme Corp (Jan 15)"
      expected_expenses:
        - type: BUSINESSMEALEXT
          found: false
      attendees: ["Jane Doe (Acme)", "Bob Johnson (Acme)"]

  # Recurring expenses not found
  missing_recurring:
    - category: FITNESS
      vendor: YMCA
      expected_months: ["November", "December", "January"]
      typical_amount: 96.00

    - category: INTERNETWIFI
      vendor: Xfinity
      expected_months: ["November", "December", "January"]
      typical_amount: 50.00
```

### Phase 5: User Walkthrough

**Present combined findings to user BEFORE processing.**

```
Based on my analysis, here's what I found:

**Receipts Found in ~/Downloads:**
✓ Verizon cellular - $80.00 (matches your recurring)
✓ Uber rideshare - $45.00 (likely from NYC trip)
✓ YMCA fitness - $96.61 (December)
✗ IMG_1234.jpg - Not a receipt (photo)
✗ screenshot.png - Not a receipt (screenshot)

**Calendar Events That May Need Receipts:**
1. NYC Trip (Jan 10-12)
   - ✓ Rideshare found (Uber $45)
   - ✗ Hotel receipt not found
   - ✗ In-flight WiFi not found
   - Do you have receipts for hotel or WiFi?

2. Customer Dinner - Acme Corp (Jan 15)
   - Attendees: Jane Doe, Bob Johnson
   - ✗ Restaurant receipt not found
   - Do you have this receipt?

**Recurring Expenses Not Found:**
Based on your history, you typically expense:
- YMCA fitness (~$96/month) - Found December, missing November, January
- Xfinity internet (~$50/month) - Missing all months
- Anthropic learning (~$110/month) - Missing all months

Do you have receipts for any of these?

**What would you like to do?**
1. Process the confirmed receipts I found
2. Provide paths to additional receipts
3. Skip certain expenses
```

### Phase 6: Process Receipts

**CRITICAL: Use ONE expense-line-item-processor agent for ALL receipts.**

The UI automation for adding line items to a report CANNOT be parallelized because:
- Chrome DevTools MCP connects to ONE browser instance
- ChromeRiver is an SPA with shared session state
- The eWallet panel is a shared resource
- The "Add Selected Transactions" flow is inherently sequential

**DO NOT spawn multiple expense-line-item-processor agents in parallel** - they will conflict with each other trying to use the same browser.

```yaml
Task (expense-line-item-processor):
  subagent_type: fe-file-expenses:expense-line-item-processor
  model: sonnet
  prompt: |
    Process ALL these receipts into expense line items.

    Report ID: <reportId>

    User Info:
      personId: <personId>
      customerId: 3035

    Allocation:
      matterId: <matterId>
      matterUniqueId: <matterUniqueId>
      clientName: <clientName>

    Historical Context:
      vendor_category_map: <from profile>
      recurring_monthly: <from profile>

    Receipts to Process:
      - path: <path_1>
        vendor_hint: <vendor from receipt-analyzer>
        amount_hint: <amount from receipt-analyzer>
        category_hint: <category from receipt-analyzer>
        calendar_match: <event details if applicable>

      - path: <path_2>
        vendor_hint: <vendor>
        amount_hint: <amount>
        category_hint: <category>

      - path: <path_3>
        ...

    Instructions:
    1. Upload ALL receipts to eWallet via email (batch upload)
    2. Wait for all receipts to appear in eWallet
    3. Navigate to report and open eWallet panel
    4. Select all relevant receipts
    5. Click "Add Selected Transactions to Report"
    6. For EACH receipt in the UI flow:
       - Fill required fields (Allocation, expense-type-specific fields)
       - Save the line item
    7. Return summary of all processed receipts

    Return: list of {status, vendor, amount, category, warnings} for each receipt
```

### Phase 7: Final Review

**Present summary and draft link - DO NOT SUBMIT.**

```yaml
report_summary:
  report_id: "<reportId>"
  name: "<cutoff_date> - <today> Expenses"
  status: DRAFT
  total_amount: XXXX.XX
  line_items_count: N

  link: "https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details"

processed_expenses:
  - vendor: Verizon
    category: MobSec Mobile
    amount: 80.00
  - vendor: Uber
    category: TAXI
    amount: 45.00

policy_warnings:
  - "WiFi expense exceeds $50 limit" (if applicable)

skipped_items:
  - "Hotel from NYC trip (user said 'no receipt')"

next_steps:
  - "Review the draft report at the link above"
  - "Submit when ready"
```

## Quick Reference

### Expense Categories

| Code | Display Name | Monthly Limit |
|------|--------------|---------------|
| INTERNETWIFI | Internet / WiFi (Home) | $50 |
| MobSec Mobile | Cell Phone | N/A (single line) |
| Fitness | Fitness | $250 |
| TAXI | Rideshare/Taxi | N/A |
| BUSINESSMEALEXT | Business Meal (External) | N/A |
| HOTEL | Hotel | N/A |
| AIRWIFI | In-Flight WiFi | N/A |
| Career Development | Learning & Development | N/A |

### Emburse URLs

| Page | URL |
|------|-----|
| Okta SSO | `https://databricks.okta.com/app/databricks_chromeriver_1/exk1n5wwxjvwa24Km1d8/sso/saml?fromHome=true` |
| Draft Reports | `https://app.ca1.chromeriver.com/index#expenses/draft` |
| Report Details | `https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details` |

## Critical UI Automation Notes

The `expense-line-item-processor` agent uses Chrome DevTools MCP for UI automation. Key learnings:

| Pattern | Best Practice |
|---------|--------------|
| **Dropdown selection** | Use `fill` tool, NOT `click` on options - Angular Material dropdowns fail with click |
| **Modifying amounts** | Click Edit button first, then `fill` the Spent field, then Save |
| **Changing category** | Enter Edit mode FIRST, then click "Edit expense item type" - modifies in place |
| **Form validation** | Look for `invalid=true` attribute - fill required fields to clear |
| **Edit mode detection** | Fields with `disableable disabled` are read-only - need Edit button |

See [emburse-expenses UI Automation](../emburse-expenses/resources/ui-automation.md) for detailed patterns.

## WHAT NOT TO DO

- **DO NOT** auto-submit reports - always leave as draft
- **DO NOT** read receipt images in main session - use subagents
- **DO NOT** run profiler and discovery in parallel - profiler first
- **DO NOT** skip receipt analysis phase - analyze files before prompting user
- **DO NOT** analyze more than 4 files at a time - batch in groups of 4
- **DO NOT** use `click` on dropdown options - use `fill` tool instead
- **DO NOT** try to fill fields before clicking Edit button

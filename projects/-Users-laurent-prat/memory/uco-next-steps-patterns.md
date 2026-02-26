# UCO Next Steps Update Patterns

## Critical Rules - NEVER VIOLATE

1. **NEVER remove previous entries** - Always preserve full history
2. **ALWAYS query existing content first** - Read before writing
3. **ALWAYS use 4-line template** - Date/Initials/Status, Last, Next, Risk
4. **ALWAYS prepend new entries** - Newest at top

## 4-Line Template Format

```
[Mon-DD] - [LP] - Status: [On track / At risk / On Hold / Delayed]
Last: [What happened since last update]
Next: [What's the next action]
Risk: [Any risks identified, or "None"]
```

### Example - Correct Format
```
Feb-26 - LP - Status: On track
Last: Weekly sync with Satish completed. London workshop Feb 20 successful.
Next: Follow up on support ticket. Continue migration phase 3.
Risk: None

Feb-25 - LP - Status: On track
Last: Bi-weekly postponed. Support ticket #00859358 opened.
Next: Continue technical work.
Risk: None
```

### Example - WRONG Format (DO NOT USE)
```
Feb-26 - LP - Status: On track. Last: Weekly sync. Next: Continue work. Risk: None
```
This single-line format loses readability and should never be used.

## Update Workflow

### Step 1: Query Existing Content
```bash
sf data query --query "SELECT Id, Name, Demand_Plan_Next_Steps__c FROM UseCase__c WHERE Id = 'aAvXXXXXXXXXXXXXXX'" --json
```

### Step 2: Prepare New Entry
Write the new 4-line entry:
```
Feb-26 - LP - Status: On track
Last: [What happened]
Next: [What's next]
Risk: [Risks or "None"]
```

### Step 3: Update with Full History
```bash
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Demand_Plan_Next_Steps__c='[NEW ENTRY]

[ALL PREVIOUS ENTRIES - COPY EXACTLY AS-IS]'"
```

## Common Status Values
- **On track** - Progressing as planned
- **At risk** - Timeline or delivery at risk
- **On Hold** - Paused, waiting on external factor
- **Delayed** - Behind schedule
- **Discovery** - Still gathering requirements

## Querying Laurent's UCOs

Always use Account.Last_SA_Engaged__c field:
```bash
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, Demand_Plan_Next_Steps__c, Account__r.Name FROM UseCase__c WHERE Account__c IN (SELECT Id FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV') AND Stages__c IN ('U2', 'U3', 'U4', 'U5') ORDER BY Account__r.Name, Stages__c"
```

## Displaying UCO Summary

### 2-Line Summary Format
```bash
sf data query --query "..." --json | jq -r '.result.records[] |
"**\(.Name)** [\(.Stages__c)] \(.Implementation_Status__c)
\(.Demand_Plan_Next_Steps__c | split("\n")[1:3] | join("\n"))
"'
```

### Table Format with Last/Next
```bash
| UCO | Stage | Status | Last | Next |
```

## Lessons Learned (Feb 2026)

### Mistake: Overwriting History
- **What happened**: Updated Next Steps with only recent entries, losing historical data
- **Impact**: Lost valuable context and audit trail
- **Fix**: Always query first, then prepend new entry to full existing content

### Mistake: Single-Line Format
- **What happened**: Used inline format instead of 4-line template
- **Impact**: Hard to read, doesn't follow team standard
- **Fix**: Always use 4-line template with proper line breaks

### Mistake: Missing Initials
- **What happened**: Forgot to include "LP" after the date
- **Impact**: No attribution for the update
- **Fix**: Always use format `[Mon-DD] - [LP] - Status: ...`

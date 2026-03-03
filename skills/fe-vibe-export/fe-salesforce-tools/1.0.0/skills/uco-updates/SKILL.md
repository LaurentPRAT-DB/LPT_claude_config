---
name: uco-updates
description: Update Use Case Objects (UCOs) with weekly status updates per AMER Emerging guidelines
---

# UCO Updates Skill

Update Use Case Objects (UCOs) with weekly status updates. UCOs should be reviewed every week and updated with any changes for UCOs in U2+.

**Reference Doc**: [UCO Management - AMER Emerging](https://docs.google.com/document/d/1cLx2xjQ8YqdxvJeFRIi3Z20xPgnaD-Mu_RNEKdzT8oM)

## Instructions

**IMPORTANT**: Use the cli-executor subagent to execute commands and summarize results

1. Ensure authenticated with Salesforce (use `/salesforce-authentication` if needed)
2. **Check user preferences** for Next Steps format (see below)
3. **Automatically discover your UCOs** using Step 0 (filters by your assignments and accounts)
4. Identify specific UCO to update from the discovered list
5. Review current UCO state
6. Update required fields per the guidelines below
7. Verify updates were applied

---

## User Preferences

Check `~/.vibe/profile` for the `next_steps_format` preference:

```bash
if [ -f ~/.vibe/profile ]; then
  grep -A2 "salesforce:" ~/.vibe/profile | grep "next_steps_format" | awk '{print $2}'
fi
```

### Next Steps Format

**short** (default) - Concise, single-line updates:
```
Jan-05 - BK - Meeting with customer Monday to review architecture
```

**verbose** - Structured, multi-line updates:
```
YYYY-MM-DD - [Initials]:
Status: [green|yellow|red] - [brief status summary, is it on track?]
Last step: [description of completed action with date]
Next step: [description of upcoming action with date] - Owner: [Name/Role]
Risk: [risk description and mitigation actions]

[... existing entries below ...]
```

If no preference is set, default to `short` format.

## Required Weekly Update Fields (U2+ UCOs)

| Field | API Field | Owner | Description |
|-------|-----------|-------|-------------|
| **Next Steps** | `Demand_Plan_Next_Steps__c` | AE | Weekly progress updates |
| **Target Onboarding Date** | `Implementation_Start_Date__c` | AE | Date dev work begins & $DBU usage starts |
| **Target Live Date** | `Full_Production_Date__c` | AE | Date dev work completes & $DBU at steady state |
| **Use Case Health** | `Implementation_Status__c` | SA | Red/Yellow/Green confidence indicator |
| **Implementation Notes** | `Implementation_Notes__c` | AE | Enablement and contact info |
| **In Plan vs Out of Plan** | `UseCaseInPlan__c` | AE | Treat like Forecast Category |
| **DSA** | `DSA__c` | DSA | DSA assigned to UCO |
| **Account Notes** | `ManagerNotes__c` | FLM | **OPTIONAL - Managers only** |

---

## Step 0: Discover Your UCOs (Default Behavior)

**This step should run automatically when the skill is invoked without a specific UCO target.**

### 0A: Get Current User Information

```bash
# Get current authenticated user email
sf org display --json | jq -r '.result.username'
```

### 0B: Find UCOs Assigned to You

Query for UCOs where you are assigned as Solution Architect, RSA, or DSA:

```bash
# Store user email
USER_EMAIL=$(sf org display --json | jq -r '.result.username')

# Find all UCOs assigned to you (SA, RSA, or DSA) in U2+ stages
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
  Account__r.Name, Solution_Architect__r.Name, rsa__r.Name, DSA__r.Name, \
  Implementation_Start_Date__c, Full_Production_Date__c, UseCaseInPlan__c, \
  LastModifiedDate \
  FROM UseCase__c \
  WHERE (Solution_Architect__r.Email = '${USER_EMAIL}' \
    OR rsa__r.Email = '${USER_EMAIL}' \
    OR DSA__r.Email = '${USER_EMAIL}') \
  AND Active__c = true \
  AND Stages__c IN ('2-Scoping','3-Evaluating','4-Confirming','5-Onboarding','6-Live') \
  ORDER BY Implementation_Status__c DESC, Stages__c, LastModifiedDate DESC" --json
```

### 0C: Find UCOs for Your Accounts (from vibe profile)

If the user has accounts configured in `~/.vibe/profile`, query UCOs for those accounts:

```bash
# Check if vibe profile exists and has accounts
if [ -f ~/.vibe/profile ]; then
  # Parse account SFDC IDs from profile (if configured)
  # This step requires the profile to have sfdc_account_id fields

  # Example query for a specific account
  sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
    Account__r.Name, Solution_Architect__r.Name, \
    Implementation_Start_Date__c, Full_Production_Date__c, UseCaseInPlan__c \
    FROM UseCase__c \
    WHERE Account__c IN ('<ACCOUNT_ID_1>', '<ACCOUNT_ID_2>') \
    AND Active__c = true \
    AND Stages__c IN ('2-Scoping','3-Evaluating','4-Confirming','5-Onboarding','6-Live') \
    ORDER BY Account__r.Name, Stages__c" --json
fi
```

### 0D: Present Summary

Use the cli-executor subagent to:
1. Execute the queries above
2. Summarize results in a clear table format showing:
   - UCO Name
   - Account
   - Stage
   - Health Status
   - Your Role (SA/RSA/DSA)
   - Target Dates
   - In Plan status
3. Group by:
   - **Priority 1**: Red/Yellow health status UCOs
   - **Priority 2**: By stage (U2, U3, U4, U5, U6)
4. Highlight:
   - UCOs with no health status set
   - UCOs with approaching target dates
   - UCOs not modified recently

**If no UCOs found**: Inform user they have no UCO assignments and offer to search by account name or UCO name instead.

---

## Step 1: Find a Specific UCO (Manual Search)

**Use these queries when you need to find a UCO not automatically discovered in Step 0.**

```bash
# Search by UCO name
sf data query --query "SELECT Id, Name, Stages__c, Account__r.Name \
  FROM UseCase__c WHERE Name LIKE '%<SEARCH_TERM>%' AND Active__c = true"

# List all active UCOs for an account
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c \
  FROM UseCase__c \
  WHERE Account__r.Name LIKE '%<ACCOUNT_NAME>%' \
  AND Active__c = true"

# List UCOs needing weekly updates (U2+) for an account
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
  Demand_Plan_Next_Steps__c, Full_Production_Date__c \
  FROM UseCase__c \
  WHERE Account__c = '<ACCOUNT_ID>' \
  AND Stages__c IN ('2-Scoping','3-Evaluating','4-Confirming','5-Onboarding','6-Live') \
  AND Active__c = true"
```

---

## Step 2: Review Current UCO State

```bash
# Get all weekly update fields for a UCO
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
  Demand_Plan_Next_Steps__c, Implementation_Start_Date__c, Full_Production_Date__c, \
  Implementation_Notes__c, UseCaseInPlan__c, DSA__c, DSA__r.Name, ManagerNotes__c, \
  Account__r.Name FROM UseCase__c WHERE Id = '<UCO_ID>'"
```

---

## Step 3: Update Fields

### Next Steps (Demand_Plan_Next_Steps__c)

**Format**: `Mon-DD - INITIALS - Update text`

Updates are prepended to the top (newest first). Include links to relevant docs where applicable.

**Example entries**:
```
Jan-05 - BK - Meeting with customer on Monday to review architecture
Dec-11 - RZ - Block is still finalizing design. Doc: https://docs.google.com/document/d/xxx
Dec-04 - RZ - Beth working with Catalyst team on test plan
```

**To update**: First read the current value, then prepend your new entry:

```bash
# 1. Get current Next Steps
sf data query --query "SELECT Demand_Plan_Next_Steps__c FROM UseCase__c WHERE Id = '<UCO_ID>'" --json

# 2. Update with new entry prepended (replace <EXISTING> with current content)
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Demand_Plan_Next_Steps__c='Jan-05 - BK - <YOUR_UPDATE>\n<EXISTING_CONTENT>'"
```

---

### Target Onboarding Date (Implementation_Start_Date__c)

Date development work is expected to begin and $DBU usage starts driving from the UCO.

- Do NOT include usage from a Pilot or POC for this date
- Date should align with U5 Stage criteria

```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Start_Date__c=2026-02-01"
```

---

### Target Live Date (Full_Production_Date__c)

Date development work is completed and $DBU usage has hit a steady state.

- Date should align with U6 Stage criteria
- If pushed out 30+ days, must include reasoning in Next Steps field

```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Full_Production_Date__c=2026-03-15"
```

---

### Use Case Health (Implementation_Status__c)

Red, Yellow, or Green based on confidence the UCO will go live by Target Live Date.

| Status | Meaning |
|--------|---------|
| **Green** | On track to hit Target Live Date |
| **Yellow** | Some risk, but still achievable |
| **Red** | Significant risk or product blockers preventing progression |

**Note**: If product blockers exist, Health should be Red and AHAs must be linked for each unique blocker.

```bash
# Set to Green
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Status__c=Green"

# Set to Yellow
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Status__c=Yellow"

# Set to Red
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Status__c=Red"
```

---

### Implementation Notes (Implementation_Notes__c)

Follow this template:

```
Enablement needed: Y/N
Enablement team engaged: Y/N
Implementation Contact: <name>
- Self Implementation: customer contact who owns the project
- Partner Implementation: partner contact who owns the project
- PS Implementation: PS will add note here
```

```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Notes__c='Enablement needed: Y\nEnablement team engaged: Y\nImplementation Contact: John Smith (Customer PM)'"
```

---

### In Plan vs Out of Plan (UseCaseInPlan__c)

Treat the same as "Forecast Category" on a commit opportunity.

- **In Plan (true)**: Confident in Live Date AND Estimated Monthly Run Rate
- **Out of Plan (false)**: Risk on Live Date OR Estimated Monthly Run Rate

```bash
# Set In Plan
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "UseCaseInPlan__c=true"

# Set Out of Plan
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "UseCaseInPlan__c=false"
```

---

### DSA (DSA__c)

DSA assigned to the UCO. Requires the User ID of the DSA.

```bash
# Find DSA User ID by name
sf data query --query "SELECT Id, Name, Email FROM User WHERE Name LIKE '%<DSA_NAME>%' AND IsActive = true"

# Find DSA User ID by email
sf data query --query "SELECT Id, Name, Email FROM User WHERE Email = '<DSA_EMAIL>'"

# Assign DSA to UCO
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "DSA__c=<USER_ID>"
```

---

### Account Notes - OPTIONAL (ManagerNotes__c)

**For managers only.** Use to flag high potential accounts or add manager-specific notes.

- Put "High Potential Accounts" on first line for high potential accounts
- For accounts with multiple UCOs, label which note is for each UCO

```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "ManagerNotes__c='High Potential Accounts\nStrong exec sponsorship, expanding to new BU'"
```

---

### Stage (Stages__c)

Update the UCO lifecycle stage when criteria are met.

| Stage | Name | Definition | Clear Indicator |
|-------|------|------------|-----------------|
| **U2** | Scoping | Pain identified, willingness to address | Customer willing to engage with SA |
| **U3** | Evaluating | Customer agrees DB could be solution. Requires: (1) Success criteria, (2) Workspace deployed, (3) Hands-on | Pilot/POC started |
| **U4** | Confirming | Customer agrees DB is best solution | Tech Win from customer |
| **U5** | Onboarding | Starting to use DBUs for this UCO | UCO driving $DBUs outside Pilot/POC |
| **U6** | Live | Dev work completed, hitting MRR target | $DBU at steady state |

**Note**: If UCO has product blocker preventing progression, stage must remain in U2.

```bash
# Valid values: 1-Validating, 2-Scoping, 3-Evaluating, 4-Confirming, 5-Onboarding, 6-Live, Lost, Disqualified
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Stages__c=3-Evaluating"
```

---

## Combined Update Example

Update multiple fields in a single command:

```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Demand_Plan_Next_Steps__c='Jan-05 - BK - POC progressing well\n<EXISTING>' \
  Implementation_Status__c=Green \
  Implementation_Start_Date__c=2026-02-01 \
  Full_Production_Date__c=2026-03-15 \
  UseCaseInPlan__c=true \
  Stages__c=3-Evaluating"
```

---

## Step 4: Verify Updates

```bash
# Confirm the updates were applied
sf data query --query "SELECT Name, Stages__c, Implementation_Status__c, \
  Implementation_Start_Date__c, Full_Production_Date__c, UseCaseInPlan__c \
  FROM UseCase__c WHERE Id = '<UCO_ID>'"
```

---

## Production Pilot vs POC

Both available when UCO moves to U3, but Production Pilot has benefits:

| Type | Environment | Data | Adoption |
|------|-------------|------|----------|
| **Production Pilot** | Production | Live customer data | Easier (already in prod) - shorter U5 |
| **POC** | Development | Dev data/architecture | Requires rebuild in prod - longer U5 |

---

## Quick Reference

| What to Update | API Field | Example Value |
|----------------|-----------|---------------|
| Next Steps | `Demand_Plan_Next_Steps__c` | `'Jan-05 - BK - Update text\n...'` |
| Target Onboarding | `Implementation_Start_Date__c` | `2026-02-01` |
| Target Live | `Full_Production_Date__c` | `2026-03-15` |
| Health | `Implementation_Status__c` | `Green`, `Yellow`, `Red` |
| Implementation Notes | `Implementation_Notes__c` | `'Enablement needed: Y\n...'` |
| In Plan | `UseCaseInPlan__c` | `true`, `false` |
| DSA | `DSA__c` | `005XXXXXXXXXXXX` (User ID) |
| Manager Notes | `ManagerNotes__c` | `'High Potential Accounts\n...'` |
| Stage | `Stages__c` | `3-Evaluating` |

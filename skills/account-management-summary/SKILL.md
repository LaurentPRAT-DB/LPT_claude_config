---
name: account-management-summary
description: Generate a comprehensive Customer Intelligence Brief for any Databricks account. Scans Salesforce, Gmail, Google Drive to collect all context, then produces a formatted Google Doc and a Google Slides territory review deck. Also populates Salesforce Account Plan (20 fields), Strategic Objectives, Partner Landscape, Whitespace By LOB, Migration Plan, and TAP Map (EB Champion + BU+1).
user_invocable: true
---

# Account Management Summary

Generate a comprehensive Customer Intelligence Brief for a given account by scanning all available data sources and producing a Google Doc.

## Trigger

When the user asks to generate an account summary, account brief, customer intelligence report, or account management summary for a specific account name.

## Input

The user provides these at the start:
1. **Account name** (required) — e.g., "MSC CARGO", "Nestle", "Swatch Group"
2. **AccountPlan Salesforce record ID** (required for scope 2+) — e.g., `252Vp00000aXqGsIAK`
3. **Scope** (optional, default: 1) — controls how much work to do (see below)

**Ask for account name and AccountPlan ID before starting** (AccountPlan ID not needed for scope 1 only).

### Scope Levels

Parse the scope from the user's arguments. Accept numeric (`1`, `2`, `3`), keyword (`doc`, `salesforce`, `slides`, `deck`), or phrase (`just the doc`, `do everything`).

| Scope | What it does | Phases executed |
|---|---|---|
| **1** (default) | **Google Doc only** — Scan Salesforce, Gmail, Drive and produce the Intelligence Brief Google Doc | Phases 0-5 |
| **2** | **Doc + Salesforce** — Everything in scope 1, plus populate Salesforce Account Plan, Strategic Objectives, Partner Landscape, Whitespace By LOB, Migration Plan, and TAP Map | Phases 0-11 |
| **3** | **Doc + Salesforce + Slides** — Everything in scope 2, plus generate the Territory Review Google Slides deck from the CHATEE template | Phases 0-12 |

**Inline help**: If the user passes `help`, `--help`, or `?` as an argument, display this usage guide and stop:

```
Usage: /account-management-summary <Account Name> [AccountPlan ID] [scope]

Scope levels:
  1 (default)  Google Doc only — Intelligence Brief from Salesforce + Gmail + Drive
  2            Doc + Salesforce — Also populates Account Plan, Strategic Objectives,
               Partner Landscape, Whitespace By LOB, Migration Plan, TAP Map
  3            Doc + Salesforce + Slides — Also generates Territory Review deck
               from the FY27 CHATEE template

Examples:
  /account-management-summary SITA
  /account-management-summary SITA 252Vp00000aXqHAIA0
  /account-management-summary SITA 252Vp00000aXqHAIA0 3
  /account-management-summary SITA, scope 2
  /account-management-summary SITA, just the doc
  /account-management-summary SITA 252Vp00000aXqHAIA0, do everything
  /account-management-summary help
```

**Scope parsing rules**:
- If user says "just the doc" / "doc only" / "scope 1" → scope 1
- If user says "salesforce" / "account plan" / "scope 2" → scope 2
- If user says "slides" / "deck" / "everything" / "all" / "scope 3" / "do everything" → scope 3
- If user says "just do phase 12" / "just the slides" / "just the deck" → skip to Phase 12 only (assumes intelligence brief data already exists — look it up on Google Drive)
- If no scope specified → default to scope 1
- If scope 2 or 3 and no AccountPlan ID provided → ask for it before proceeding

The AccountPlan is a single Salesforce record (`AccountPlan` sObject) that contains all of the following sections as either direct fields or child records:
- Phase 6: Account Plan text fields (company overview, vision, strategy, SWOT, etc.)
- Phase 7: Strategic Objectives (`StrategicPriority__c` children)
- Phase 8: Partner Landscape (`AccountPlanRelated__c` children, RT: Partner Landscape)
- Phase 9: Whitespace By LOB (`AccountPlanRelated__c` children, RT: Whitespace By LOB)
- Phase 10: Migration Plan (`AccountPlanRelated__c` children, RT: Migration Plan)
- Phase 11: TAP Map (`AccountPlanRelated__c` children, RT: EB Champion) + Whitespace By BU+1

All child records reference the same AccountPlan via `AccountPlan__c`. Do NOT query for the AccountPlan — use the ID provided by the user.

## Workflow

**Before starting**: Parse the user's arguments to determine account name, AccountPlan ID, and scope level. If arguments contain `help`/`--help`/`?`, display the inline help text above and stop.

### Phase 0: Verify AccountPlan & Get Account ID (Start Here)

**IMPORTANT**: Start by verifying the AccountPlan record. This gives you the Account.Id needed for ALL subsequent queries, and avoids wasting time if the ID is wrong.

```bash
sf data query --query "SELECT Id, Name, Status, Account.Name, Account.Id FROM AccountPlan WHERE Id = 'ACCOUNT_PLAN_ID'" --json 2>/dev/null
```

Extract `Account.Id` from the result — use it as `ACCOUNT_ID` in all Phase 1 queries below.

### Phase 1: Salesforce Discovery

Query Salesforce to get business context. All queries use `sf data query`.

**CRITICAL**: Always append `2>/dev/null` to ALL `sf data query` commands. The sf CLI prints update warnings to stderr which corrupts JSON output when piped to other tools.

**Step 1.1 - Find the Account**
```bash
sf data query --query "SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees, Description, OwnerId, Owner.Name, Last_SA_Engaged__c, BillingCity, BillingState, BillingCountry FROM Account WHERE Name LIKE '%ACCOUNT_NAME%' LIMIT 5" --json 2>/dev/null
```

**Step 1.2 - Get Opportunities (deal history)**
```bash
sf data query --query "SELECT Id, Name, StageName, Amount, CloseDate, Type, CreatedDate, Description, ForecastCategory, NextStep, Owner.Name, Probability FROM Opportunity WHERE AccountId = 'ACCOUNT_ID' ORDER BY CreatedDate DESC" --json 2>/dev/null
```

**Step 1.3 - Get Use Cases (UCOs)**
```bash
sf data query --query "SELECT Id, Name, Use_Case_Description__c, Demand_Plan_Next_Steps__c, CreatedDate, LastModifiedDate FROM UseCase__c WHERE Account__c = 'ACCOUNT_ID' ORDER BY CreatedDate DESC" --json 2>/dev/null
```
**Note**: Many documented UseCase__c fields do NOT exist in the org (`Use_Case_Stage__c`, `Use_Case_Workload__c`, `Use_Case_Status__c`, `Technical_Win__c`, `POC_Doc__c`, `Artifact_Link__c`). Only the fields above work reliably. If you need to discover additional fields, use REST API describe (not `sf sobject describe` which corrupts JSON output with stderr warnings).

**Step 1.4 - Get Contacts**
```bash
sf data query --query "SELECT Id, Name, Title, Email, Department, Phone FROM Contact WHERE AccountId = 'ACCOUNT_ID' ORDER BY LastModifiedDate DESC" --json 2>/dev/null
```

**Step 1.5 - Get Opportunity Contact Roles (stakeholder mapping)**
```bash
sf data query --query "SELECT Id, ContactId, Contact.Name, Contact.Title, Contact.Email, Contact.Department, Role FROM OpportunityContactRole WHERE Opportunity.AccountId = 'ACCOUNT_ID'" --json 2>/dev/null
```

**Step 1.6 - Get Events (meetings)**
```bash
sf data query --query "SELECT Id, Subject, StartDateTime, EndDateTime, Description, CreatedDate, OwnerId FROM Event WHERE AccountId = 'ACCOUNT_ID' ORDER BY StartDateTime ASC" --json 2>/dev/null
```

**Step 1.7 - Get Tasks (non-outreach activities)**
```bash
sf data query --query "SELECT Id, Subject, ActivityDate, CreatedDate, Description FROM Task WHERE AccountId = 'ACCOUNT_ID' AND (NOT Subject LIKE '%Outreach%') ORDER BY CreatedDate ASC LIMIT 50" --json 2>/dev/null
```
**Note**: The `NOT` in SOQL must be wrapped in parentheses: `AND (NOT Subject LIKE '%Outreach%')`. Without parentheses, you get "unexpected token: 'NOT'".

### Phase 2: Gmail Search

Search for all emails related to the account in the last 12-24 months.

```bash
TOKEN=$(python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-auth/resources/google_auth.py token 2>/dev/null)

# Search with account name and domain
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=(ACCOUNT_NAME+OR+domain.com)+newer_than:24m&maxResults=50" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

For each message, get metadata:
```bash
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages/MSG_ID?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Date" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

Read full body of the 10 most substantive emails (skip outreach, calendar RSVPs, automated notifications):
```bash
python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/gmail/resources/gmail_builder.py read-message --message-id "MSG_ID"
```

### Phase 3: Google Drive Search

Search for documents related to the account.

```bash
TOKEN=$(python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-auth/resources/google_auth.py token 2>/dev/null)

# Search Drive for account-related docs
curl -s "https://www.googleapis.com/drive/v3/files?q=fullText+contains+'ACCOUNT_NAME'&fields=files(id,name,mimeType,modifiedTime,webViewLink)&pageSize=30&orderBy=modifiedTime+desc" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

Read key documents (presentations, spreadsheets, docs) using appropriate APIs:
- **Presentations**: Google Slides API to extract text from all slides
- **Spreadsheets**: Export as CSV
- **Documents**: Google Docs API to read content

### Phase 4: Compile Intelligence Brief

Write a markdown file to `/tmp/account_brief_ACCOUNTNAME.md` (use sanitized account name to avoid collisions with other runs). Clean up this file after the Google Doc is created.

Use the following structure:

```markdown
# [Account Name] - Customer Intelligence Brief

## Document Purpose
Brief context on why this document exists.

## Executive Summary
3-5 paragraph overview: who they are, relationship status, current deal, key metrics, strategic importance.

Key facts at a glance (bullet list):
- Revenue/spend figures
- Active opportunity details
- Platform/cloud
- Primary competitor
- Account team

## Account Overview
### Company Profile
Company details, industry, size, headquarters, ownership.

### Strategic Priorities
Customer's own business priorities and digital transformation goals.

## Databricks Team
List all Databricks personnel involved with roles.

## Key Stakeholders
Organized by level:
### Executive / Decision Makers
### Data & Analytics Leadership
### Technical Champions
### Procurement

## Technology Landscape
### Current Architecture
Cloud, storage, compute, orchestration, governance, IaC.

### Competitor Presence
Who else is in the environment and positioning context.

### Partners
SIs and technology partners involved.

## Opportunity History
### Closed/Historical (table)
### Active (table)

## Active Use Cases (table)
If UCOs exist, list them with stage, owner, and notes.

## Consumption Forecast (table if data available)

## Timeline of Major Events
Chronological from earliest to most recent, organized by year/quarter.
Include: deal milestones, meetings, technical decisions, incidents, personnel changes, strategic pivots.
Also include upcoming/planned events.

## Risks and Challenges
Key risks: competition, champion departures, procurement delays, technical issues, underutilization.

## Growth Strategy and Recommendations
### Near-Term (current quarter)
### Medium-Term (next 2 quarters)
### Long-Term (1-2 years)

## Key Documents and Resources
Links to all relevant Google Drive documents found.
```

### Phase 5: Create Google Doc

Use the markdown-to-gdocs converter:
```bash
cd ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-docs
python3 resources/markdown_to_gdocs.py --input /tmp/account_brief_ACCOUNTNAME.md --title "[Account Name] - Customer Intelligence Brief - [Month Year]"
```

Then try converting markdown tables to native tables (benign if it finds nothing — `markdown_to_gdocs.py` often handles tables during initial creation):
```bash
python3 resources/markdown_tables_to_gdocs.py --doc-id "DOC_ID"
```

**After doc creation**: If Gmail/Drive agents are still running, append their findings to the Google Doc using the Docs API `batchUpdate` with `insertText` requests. Get the document end index first via `documents.get`, then insert at that position.

**Cleanup**: Delete the temp markdown file after the Google Doc is created:
```bash
rm -f /tmp/account_brief_ACCOUNTNAME.md
```

Share with Databricks domain:
```bash
TOKEN=$(python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-auth/resources/google_auth.py token 2>/dev/null)
curl -s -X POST "https://www.googleapis.com/drive/v3/files/DOC_ID/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{"type": "domain", "role": "reader", "domain": "databricks.com"}'
```

### Phase 6: Populate Salesforce Account Plan

**SCOPE GATE**: Stop here if scope = 1. Phases 6-11 only run for scope >= 2. Phases 6-12 only run for scope = 3.

Use the **AccountPlan record ID** provided by the user at the start. This same ID is used across ALL subsequent phases (6-11).

**Step 6.1 - AccountPlan already verified in Phase 0** — skip if you already have the Account.Id from Phase 0. If not:
```bash
sf data query --query "SELECT Id, Name, Status, Account.Name, Account.Id FROM AccountPlan WHERE Id = 'ACCOUNT_PLAN_ID'" --json 2>/dev/null
```

**Step 6.2 - Discover AccountPlan fields**
Use the REST API to describe the object (sf CLI `sobject describe` doesn't work for AccountPlan):
```python
import subprocess, json, urllib.request
result = subprocess.run(["sf", "org", "display", "--json"], capture_output=True, text=True)
org_info = json.loads(result.stdout)
token = org_info["result"]["accessToken"]
url_base = org_info["result"]["instanceUrl"]

req = urllib.request.Request(f"{url_base}/services/data/v66.0/sobjects/AccountPlan/describe")
req.add_header("Authorization", f"Bearer {token}")
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    for f in data['fields']:
        if f.get('updateable'):
            print(f"{f['name']:45s} {f['type']:15s} label={f.get('label','')}")
```

**Step 6.3 - Map intelligence to AccountPlan fields**

| Field API Name | Content Source | Description |
|---|---|---|
| `Status` | Set to "Active" | Plan status |
| `StartDate` / `EndDate` | Current FY period | e.g., 2026-02-01 to 2027-01-31 |
| `CompanyIndustryOverview__c` | Brief § Company Profile | Company profile, revenue, employees, leadership roster |
| `AccountVision` | Brief § Growth Strategy | Target state vision for Databricks platform |
| `AccountStrategicPriorities` | Brief § Use Cases + Strategy | 5-6 numbered strategic priorities |
| `AccountPrfmIndicators` | Brief § Consumption Forecast | Consumption metrics, contract details, UC pipeline |
| `AccountIndustryTrends` | Industry context + Brief | Industry-specific technology trends |
| `AccountChallenges` | Brief § Risks | Numbered list of account challenges |
| `AccountCompetitors` | Brief § Competitor Presence | Competitor names with positioning context |
| `AccountCompetitiveStrengths` | Brief § Technology Landscape | Our competitive advantages (numbered) |
| `AccountCmptvWeaknesses` | Brief § Risks | Our competitive weaknesses (numbered) |
| `RelationshipStrengths` | Brief § Stakeholders + Timeline | Strong engagement points, champion, cadence |
| `RelationshipWeaknesses` | Brief § Risks | C-level gaps, contractor dependency, visibility gaps |
| `RelationshipOpportunities` | Brief § Growth Strategy | Events, expansion, new use cases, cross-sell |
| `RelationshipThreats` | Brief § Risks | Competition, champion loss, cost incidents |
| `Current_State_Pains_Challenges_The_W__c` | Brief § Technology + Risks | Current state description + 6 key pains |
| `Data_AI_Strategy_Value_Roadmap_Exec__c` | Brief § Growth Strategy | 4-phase value roadmap with execution priorities |
| `Strategic_Priorities_Long_Term_Data__c` | Brief § Growth Strategy Long-Term | 7 long-term strategic priorities (2-3 year vision) |
| `Notes` | Operational context | Communication protocols, active incidents, key dates, tracking links |

**Step 6.4 - Update via REST API (NOT sf CLI)**

The `sf data update record` CLI struggles with multi-line text and special characters. Use the Salesforce REST API directly:

```python
import subprocess, json, urllib.request, urllib.error

RECORD_ID = "ACCOUNT_PLAN_ID"

result = subprocess.run(["sf", "org", "display", "--json"], capture_output=True, text=True)
org_info = json.loads(result.stdout)
token = org_info["result"]["accessToken"]
url_base = org_info["result"]["instanceUrl"]

payload = {
    "Status": "Active",
    "StartDate": "2026-02-01",
    "EndDate": "2027-01-31",
    "CompanyIndustryOverview__c": "...",
    "AccountVision": "...",
    # ... all other fields
}

data = json.dumps(payload).encode('utf-8')
url = f"{url_base}/services/data/v66.0/sobjects/AccountPlan/{RECORD_ID}"
req = urllib.request.Request(url, data=data, method='PATCH')
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Content-Type", "application/json")

with urllib.request.urlopen(req) as resp:
    print(f"Status: {resp.status}")  # 204 = success
```

**Important**: Use API version `v66.0` — earlier versions (e.g., v59.0) return 404 for AccountPlan.

### Phase 7: Create Strategic Objectives

Create 3-5 outcome-driven Strategic Objectives as child records of the AccountPlan. These are the "north star" initiatives with clear owners, target dates, and measurable KPIs.

**Step 7.1 - Get key contact IDs for PrimaryCustomerExec**
```bash
sf data query --query "SELECT Id, Name, Title, Email FROM Contact WHERE AccountId = 'ACCOUNT_ID' AND (Name LIKE '%Champion%' OR Name LIKE '%CIO%' OR ...) ORDER BY Name" --json 2>/dev/null
```
**Note**: For names with accents (e.g., `René`), use `LIKE '%LastName%'` instead of exact match — SOQL doesn't handle accent-insensitive matching.

**Step 7.2 - Check for existing Strategic Objectives**
```bash
sf data query --query "SELECT Id, Name, StrategicObjective__c, Status__c FROM StrategicPriority__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID'" --json 2>/dev/null
```

**Step 7.3 - Define 3-5 Strategic Objectives**

Each objective maps to the `StrategicPriority__c` object with these fields:

| Field API Name | Type | Description |
|---|---|---|
| `AccountPlan__c` | reference | Link to parent AccountPlan (set at creation, read-only after) |
| `StrategicObjective__c` | string(255) | Outcome-driven title (e.g., "Complete SQL Migration & Drive 277% Growth") |
| `Status__c` | picklist | `Not started`, `In progress`, `Complete`, `Blocked` |
| `TargetDate__c` | date | Target completion date (YYYY-MM-DD) |
| `MeasureKPI__c` | string(255) | Measurable success criteria (e.g., "$825K consumption; 100% migration") |
| `PrimaryCustomerExec__c` | reference | Salesforce Contact ID of the customer executive owner |
| `IndustryImperative__c` | string(255) | Why this matters in the customer's industry |
| `YourPlan__c` | textarea(32768) | 5-7 numbered action steps |
| `BusinessImpact__c` | textarea(32768) | Revenue impact, stickiness, strategic value |
| `DependenciesAsksIncludingSrcData__c` | textarea(32768) | Internal dependencies, asks, blockers |

**Step 7.4 - Recommended Objective Templates**

Derive 3-5 objectives from the intelligence brief. Common patterns for Databricks accounts:

1. **Platform Migration & Consumption Growth** — Complete migration, drive consumption to target
   - Source: Brief § Use Cases (migration UCs) + Consumption Forecast
   - KPI: Consumption target + migration completion %
   - Owner: Technical champion (Head of Data/Technology)

2. **AI/ML Platform Adoption** — Establish Databricks as the AI platform
   - Source: Brief § AI/ML initiatives (AgentBricks, Genie, MCP, Model Serving)
   - KPI: Number of AI use cases in production
   - Owner: Head of AI / Data Science lead

3. **Geographic / Organizational Expansion** — Expand to new regions or business units
   - Source: Brief § Growth Strategy Long-Term (EU expansion, cross-office, cross-desk)
   - KPI: New workspace live, headcount onboarded, incremental consumption
   - Owner: Regional technology leader

4. **Executive Relationship Elevation** — Move from technical to C-level engagement
   - Source: Brief § Risks (limited C-level engagement) + Events (AI Days, DAIS)
   - KPI: Executive event attendance, QBR established, C-level sponsor
   - Owner: CIO or CTO (target executive)

5. **Competitive Defense** — Neutralize competitive threats
   - Source: Brief § Competitor Presence + Competitive Strengths/Weaknesses
   - KPI: Win competitive evaluation areas, no new competitor workloads
   - Owner: Technical champion who owns competitive evaluation

**Step 7.5 - Create via REST API**

```python
objectives = [
    {
        "AccountPlan__c": "ACCOUNT_PLAN_ID",
        "StrategicObjective__c": "Complete Platform Migration & Drive Growth",
        "Status__c": "In progress",
        "TargetDate__c": "2026-12-31",
        "MeasureKPI__c": "$825K consumption in 2026; 100% migration complete",
        "PrimaryCustomerExec__c": "CONTACT_ID",
        "IndustryImperative__c": "Industry-specific reason this matters",
        "YourPlan__c": """1. Action step one
2. Action step two
3. Action step three
4. Action step four
5. Action step five""",
        "BusinessImpact__c": """Revenue impact and strategic value description.
Platform stickiness and competitive positioning.""",
        "DependenciesAsksIncludingSrcData__c": """- Internal dependency 1
- Ask from product/support team
- Blocker to resolve"""
    },
    # ... repeat for each objective
]

for obj in objectives:
    data = json.dumps(obj).encode('utf-8')
    req = urllib.request.Request(
        f"{url_base}/services/data/v66.0/sobjects/StrategicPriority__c",
        data=data, method='POST'
    )
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
        print(f"Created: {result['id']}")
```

**Step 7.6 - Verify**
```bash
sf data query --query "SELECT Name, StrategicObjective__c, Status__c, TargetDate__c, MeasureKPI__c, PrimaryCustomerExec__r.Name FROM StrategicPriority__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID' ORDER BY TargetDate__c" --json 2>/dev/null
```

### Phase 8: Populate Partner Landscape

Map the partner ecosystem to drive co-sell and delivery strategy. Uses `AccountPlanRelated__c` with RecordType "Partner Landscape".

**Step 8.1 - Get Record Type ID for Partner Landscape**
```python
# From AccountPlanRelated__c describe:
# RecordType "Partner Landscape" ID: 012Vp000002oeCRIAY
# Other RecordTypes: EB Champion, Migration Plan, Strategic Priority Use Cases, Whitespace By BU+1, Whitespace By LOB
```

**Step 8.2 - Find existing Account Partners**
```bash
sf data query --query "SELECT Id, Name, Partner_Account__r.Name, Partner_Role__c FROM Account_Partner__c WHERE Account__c = 'ACCOUNT_ID'" --json 2>/dev/null
```

**Step 8.3 - Check existing Partner Landscape records**
```bash
sf data query --query "SELECT Id, Name, Details__c FROM AccountPlanRelated__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID' AND RecordType.Name = 'Partner Landscape'" --json 2>/dev/null
```

**Step 8.4 - Field mapping for Partner Landscape records**

| Field API Name | Type | Description |
|---|---|---|
| `AccountPlan__c` | reference | Link to parent AccountPlan |
| `RecordTypeId` | reference | Must be Partner Landscape RT ID |
| `AccountPartner__c` | reference | Link to Account_Partner__c (if one exists) |
| `AccountTeamSentimentOfPartner__c` | picklist | `Red`, `Amber`, `Green` — YOUR key input |
| `CustomerSentimentOfPartner__c` | picklist | `Red`, `Amber`, `Green` — YOUR key input |
| `RelatedContact__c` | reference | Salesforce Contact ID |
| `RelatedStrategicPriority__c` | reference | Link to StrategicPriority__c |
| `DepartmentsLOBsLeveraging__c` | string(255) | Departments using this partner |
| `Details__c` | string(255) | Short description of the partner role |
| `CompetitorProducts__c` | multipicklist | e.g., `Snowflake`, `Microsoft Fabric` (use for competitors) |
| `IncumbentTechnology__c` | string(255) | Competitor technology name |
| `ImplementationFundingStrategy__c` | string(255) | Funding approach |
| `NextStepsActions__c` | textarea(32768) | Bulleted action items |
| `WhitespaceNotes__c` | textarea(32768) | Strategic context and rationale |

**Workload status fields** (each is a picklist: `Live`, `Actively Pursuing`, `Potential`, `Blocked/No Fit`, `Lost/Competitor`):
- `DataEngineering__c`, `DataWarehousing__c`, `DataGovernance__c`
- `AgentBricks__c`, `AIBI__c`, `Collaboration__c`
- `DataFormatsAndLakehouseStorage__c`, `Lakebase__c`

**Step 8.5 - Recommended Partner Records to Create**

Derive from the intelligence brief. Common patterns:

1. **Cloud Provider (AWS/Azure/GCP)** — Force multiplier
   - Sentiment: Usually Green/Green
   - Source: Brief § AWS/Cloud Partnership, joint syncs, credits
   - Link to: AccountPartner__c if exists + Migration strategic priority

2. **SI / PS Delivery Partners** — Co-delivery
   - Sentiment: Green if actively delivering, Amber if stalled/scoping
   - Source: Brief § Partners & Consultants
   - Link to: Migration or AI strategic priority

3. **Staff Augmentation Contractors** — Embedded resources
   - Sentiment: Green if engaged, Amber if continuity risk
   - Source: Brief § Key Contacts (identify contractors)
   - Note contractor dependency as risk in WhitespaceNotes

4. **Competitors** — Threat mapping
   - Team Sentiment: Red (competitive threat)
   - Customer Sentiment: Amber (evaluating) or Red (favoring competitor)
   - Set workload fields to `Lost/Competitor` where they have presence
   - Set to `Actively Pursuing` where we are competing
   - Source: Brief § Competitor Presence

**Step 8.6 - Create Account_Partner__c records (prerequisite for Partner Name display)**

The Partner Landscape UI only shows a Partner Name when `AccountPartner__c` is populated on the `AccountPlanRelated__c` record. To populate it, you need `Account_Partner__c` records linking the account to each partner.

**Key schema notes:**
- `Account__c`: **createable but NOT updateable** — must be set in the POST payload
- `Partner_Account__c`: reference to the partner's Account record — **required** (trigger throws NullPointerException if null)
- RecordTypes: Cloud (`0128Y0000026OFYQA2`), Consulting & SI (`0128Y0000026OFZQA2`), ISV, Reseller

**Partner_Engagement_Stage__c valid values:**
- `0 - Partner Target Account`
- `1 - Known Partner Account, Not Engaged`
- `2 - Engaged with Partner in Sales (Land)`
- `3 - Engaged with C&SI Partner in Delivery (Land)`
- `4 - Engaged with Partner in Sales (Expansion)`
- `5 - Engaged with C&SI Partner in Delivery (Expansion)`
- `6 - Engaged with ISV Partner in Delivery (Land)`
- `7 - Engaged with ISV Partner in Delivery (Expansion)`

**Partner_Role__c valid values:** `Sales`, `Implementation`, `Reseller`, `Integration`, `Cloud`

```python
# Search for partner's Account record first
partner_account_id = sf_query("SELECT Id FROM Account WHERE Name LIKE '%PARTNER_NAME%' LIMIT 1")

account_partner = {
    "Account__c": "CUSTOMER_ACCOUNT_ID",  # createable, NOT updateable
    "RecordTypeId": "0128Y0000026OFZQA2",  # Consulting & SI
    "Partner_Account__c": "PARTNER_ACCOUNT_ID",  # REQUIRED — trigger fails if null
    "Partner_Description__c": "Description of partner role",
    "Partner_Role__c": "Implementation",
    "Partner_Engagement_Stage__c": "3 - Engaged with C&SI Partner in Delivery (Land)",
    "Is_Shared__c": False,
    "See_Opportunity_with_Databricks__c": False,
    "Primary_AWS_Partner__c": False,
    "Primary_Azure_Partner__c": False,
}

data = json.dumps(account_partner).encode('utf-8')
req = urllib.request.Request(
    f"{url_base}/services/data/v66.0/sobjects/Account_Partner__c",
    data=data, method='POST'
)
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Content-Type", "application/json")
# Response contains {'id': 'new_account_partner_id'}
```

**Gotcha**: If the partner company has no Account record in Salesforce, you cannot create an `Account_Partner__c` record (the trigger requires `Partner_Account__c`). In this case, the Partner Name column will remain blank in the Partner Landscape UI.

**Step 8.7 - Create AccountPlanRelated__c records**

**Important**: The `Name` field is auto-generated (read-only) — do NOT include it in the payload.

```python
partner = {
    "AccountPlan__c": "ACCOUNT_PLAN_ID",
    "RecordTypeId": "012Vp000002oeCRIAY",  # Partner Landscape
    "AccountPartner__c": "ACCOUNT_PARTNER_ID",  # from Step 8.6 — required for Partner Name display
    "AccountTeamSentimentOfPartner__c": "Green",
    "CustomerSentimentOfPartner__c": "Green",
    "RelatedContact__c": "CONTACT_ID",
    "RelatedStrategicPriority__c": "STRATEGIC_PRIORITY_ID",
    "Details__c": "Short description of partner role",
    "DataEngineering__c": "Live",
    "DataWarehousing__c": "Live",
    "AgentBricks__c": "Actively Pursuing",
    # ... other workload fields
    "NextStepsActions__c": "• Action item 1\n• Action item 2",
    "WhitespaceNotes__c": "Strategic context..."
}

data = json.dumps(partner).encode('utf-8')
req = urllib.request.Request(
    f"{url_base}/services/data/v66.0/sobjects/AccountPlanRelated__c",
    data=data, method='POST'
)
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Content-Type", "application/json")
with urllib.request.urlopen(req) as resp:
    result = json.loads(resp.read())
    print(f"Created: {result['id']}")
```

**Step 8.8 - Link existing AccountPlanRelated__c to Account_Partner__c**

If you created `AccountPlanRelated__c` records before creating `Account_Partner__c` records, update them:

```python
req = urllib.request.Request(
    f"{url_base}/services/data/v66.0/sobjects/AccountPlanRelated__c/{apr_id}",
    data=json.dumps({"AccountPartner__c": account_partner_id}).encode('utf-8'),
    method='PATCH'
)
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Content-Type", "application/json")
# 204 = success
```

**Step 8.9 - Verify**
```bash
sf data query --query "SELECT Name, Details__c, AccountTeamSentimentOfPartner__c, CustomerSentimentOfPartner__c FROM AccountPlanRelated__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID' AND RecordType.Name = 'Partner Landscape'" --json 2>/dev/null
```

### Phase 9: Whitespace By LOB

Create a "hunting map" showing product penetration vs. whitespace by line of business.

**Step 9.1 - RecordType ID**
- Whitespace By LOB: `012Vp000002oeCUIAY`

**Step 9.2 - Field mapping**

| Field | Type | Description |
|---|---|---|
| `LOBName__c` | string(255) | Line of business name — YOUR key input |
| `AccountPlan__c` | reference | Parent AccountPlan |
| `RecordTypeId` | reference | Must be Whitespace By LOB RT |
| `RelatedContact__c` | reference | LOB owner/champion Contact ID |
| `RelatedStrategicPriority__c` | reference | Linked strategic objective |
| `RelatedUseCase__c` | reference | Linked UCO if exists |
| `DepartmentsLOBsLeveraging__c` | string(255) | Department names |
| `Details__c` | string(255) | Short description |
| `UCOCreated__c` | picklist | `Yes` / `No` |
| `EstimatedTAM__c` | currency | Total addressable market for this LOB |
| `EstimatedDatabricks__c` | percent | Estimated Databricks share of TAM |
| `DatabricksGoLiveQrtr__c` | picklist | `FY'27 Q1` through `FY'28 Q1` |
| `IncumbentTechnology__c` | string(255) | Free text incumbent tools |
| `IncumbentTools__c` | multipicklist | From standard tool list (semicolon-separated) |
| `CompetitorProducts__c` | multipicklist | From standard competitor list (semicolon-separated) |
| `WhitespaceNotes__c` | textarea(32768) | Strategic context — the "why" |
| `NextStepsActions__c` | textarea(32768) | Bulleted action items |

**Workload status fields** (picklist: `Live`, `Actively Pursuing`, `Potential`, `Blocked/No Fit`, `Lost/Competitor`):
- `DataEngineering__c`, `DataWarehousing__c`, `DataGovernance__c`
- `AgentBricks__c`, `AIBI__c`, `Collaboration__c`
- `DataFormatsAndLakehouseStorage__c`, `Lakebase__c`

**Step 9.3 - Derive LOBs from intelligence brief**

Identify 4-6 LOBs from the customer's organizational structure and use cases:
1. **Primary technical team** — where Databricks is already deployed (most fields = Live)
2. **AI/ML team** — if separate from primary (AgentBricks/AIBI = Actively Pursuing)
3. **HQ / Regional teams** — expansion targets (most fields = Potential)
4. **Business user teams** — analytics consumers (AIBI = Actively Pursuing, rest = Potential)
5. **Data science / specialized** — niche workloads (DataEngineering = Live, rest varies)

**Step 9.4 - Create via REST API**

```python
lob = {
    "LOBName__c": "Front Office Technology",
    "AccountPlan__c": "ACCOUNT_PLAN_ID",
    "RecordTypeId": "012Vp000002oeCUIAY",  # Whitespace By LOB
    "RelatedContact__c": "CONTACT_ID",
    "RelatedStrategicPriority__c": "STRATEGIC_PRIORITY_ID",
    "Details__c": "Primary LOB - data platform and analytics",
    "DataEngineering__c": "Live",
    "DataWarehousing__c": "Live",
    "AgentBricks__c": "Actively Pursuing",
    "AIBI__c": "Potential",
    # ... set each workload field
    "IncumbentTools__c": "Microsoft SQL Server;Snowflake",
    "CompetitorProducts__c": "Snowflake;Microsoft SQL Server",
    "EstimatedTAM__c": 500000,
    "EstimatedDatabricks__c": 60,
    "DatabricksGoLiveQrtr__c": "FY'27 Q1",
    "UCOCreated__c": "Yes",
    "WhitespaceNotes__c": "Strategic context...",
    "NextStepsActions__c": "• Action 1\n• Action 2",
}
# POST to /services/data/v66.0/sobjects/AccountPlanRelated__c
```

**Step 9.5 - Verify**
```bash
sf data query --query "SELECT LOBName__c, DataEngineering__c, DataWarehousing__c, AgentBricks__c, AIBI__c FROM AccountPlanRelated__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID' AND RecordType.Name = 'Whitespace By LOB'" --json 2>/dev/null
```

### Phase 10: Migration Plan

Create time-bound execution plan showing what moves, by when, with whom, and how we win.

**RecordType ID**: `012Vp000002oeCQIAY` (Migration Plan)

**Step 10.1 - Derive migration workstreams from intelligence brief**

Look for: database migrations, platform migrations, AI/ML platform adoption, regional expansions. Each workstream = 1 record.

**Step 10.2 - Key fields** (same object as LOB/Partner, different RT)

| Field | Description |
|---|---|
| `LOBName__c` | Workstream name (e.g., "SQL Data Platform Migration (UC-1)") |
| `Category__c` | Picklist: `Data Engineering`, `Data Warehouse`, `Agent Bricks (AI/ML & Agents)`, etc. |
| `RelatedContact__c`, `RelatedStrategicPriority__c`, `RelatedUseCase__c` | Link to owner, objective, UCO |
| Workload status fields | `Live`/`Actively Pursuing`/`Potential` per product area |
| `IncumbentTools__c`, `CompetitorProducts__c` | Semicolon-separated multipicklist |
| `EstimatedTAM__c`, `EstimatedDatabricks__c`, `DatabricksGoLiveQrtr__c` | Sizing and timeline |
| `WhitespaceNotes__c` | Migration context, scope, dependencies |
| `NextStepsActions__c` | Bulleted action items with dates |

**Step 10.3 - Create via REST API** (same POST pattern as Phase 9, just use RT `012Vp000002oeCQIAY`)

### Phase 11: TAP Map (EB Champion + BU+1)

Populate the TAP (TAM, Architecture, Powerbase) Map visualization in the Account Plan UI. This requires a **two-layer approach**:

1. **EB Champion records** — drive the TAP Map UI tabs (required for visibility)
2. **BU+1 records** — store deeper whitespace detail (notes, next steps, departments)

**Step 11.1 - RecordType IDs**
- EB Champion: `012Vp000002oeCPIAY`
- Whitespace By BU+1: `012Vp000002oeCTIAY`

**Step 11.2 - Create EB Champion records (one per relevant TAP tab)**

Valid `Category__c` values for EB Champion (these are the TAP Map UI tabs):
`Ingest & Transform`, `ML Stack`, `Data Warehouse`, `Data Sharing`, `Data Governance`, `GenAI Stack`, `Data Format`, `Lakebase / OLTP`

**Note**: `GenAI Stack` (not `Gen AI`) — the EB Champion and BU+1 RecordTypes have different valid picklist values for `Category__c`.

```python
eb_champion = {
    "AccountPlan__c": "ACCOUNT_PLAN_ID",
    "RecordTypeId": "012Vp000002oeCPIAY",  # EB Champion
    "Category__c": "Data Warehouse",
    "RelatedContact__c": "CONTACT_ID",  # EB/Champion contact
    "EstimatedTAM__c": 500000,
    "EstimatedDatabricks__c": 60,  # percent 0-100
    "IncumbentTools__c": "Microsoft SQL Server;Snowflake",  # semicolon-separated multipicklist
}
# POST to /services/data/v66.0/sobjects/AccountPlanRelated__c
```

Fields are minimal — EB Champion records do NOT have Notes/NextSteps/Details fields. Skip irrelevant tabs (e.g., `Data Format`, `Lakebase / OLTP` if customer doesn't use those).

**Step 11.3 - Create BU+1 records (deeper detail per product area)**

Valid `Category__c` values for BU+1:
`Ingest & Transform`, `ML Stack`, `Data Warehouse`, `Gen AI`, `Data Sharing`, `Data Governance`, `Cloud Data`, `Data Analytics`, `Data Science & AI`, `Data Management & Storage`, `Streaming & Ingestion`

**Category mapping from product areas**: Data Engineering → `Ingest & Transform`, Agent Bricks/ML → `Gen AI` or `ML Stack`, AI/BI → `Data Analytics`, Data Warehouse → `Data Warehouse`, Unity Catalog → `Data Governance`

```python
bu_plus_one = {
    "AccountPlan__c": "ACCOUNT_PLAN_ID",
    "RecordTypeId": "012Vp000002oeCTIAY",  # Whitespace By BU+1
    "BuPlusOneName__c": "Data Warehouse Modernization",  # display name (not Name)
    "Category__c": "Data Warehouse",
    "EstimatedTAM__c": 500000,
    "EstimatedDatabricks__c": 60,
    "IncumbentTechnology__c": "Microsoft SQL Server, legacy on-prem",
    "IncumbentTools__c": "Microsoft SQL Server;Snowflake",
    "DepartmentsLOBsLeveraging__c": "Front Office Technology",
    "RelatedContact__c": "CONTACT_ID",
    "RelatedStrategicPriority__c": "STRATEGIC_PRIORITY_ID",
    "WhitespaceNotes__c": "Strategic context...",
    "NextStepsActions__c": "• Action 1\n• Action 2",
}
# POST to /services/data/v66.0/sobjects/AccountPlanRelated__c
```

**Step 11.4 - Verify**
```bash
sf data query --query "SELECT Category__c, RelatedContact__r.Name, EstimatedTAM__c, EstimatedDatabricks__c FROM AccountPlanRelated__c WHERE AccountPlan__c = 'ACCOUNT_PLAN_ID' AND RecordType.Name = 'EB Champion'" --json 2>/dev/null
```

### Phase 12: Generate Territory Review Deck (Google Slides)

**SCOPE GATE**: Stop here if scope <= 2. Phase 12 only runs for scope = 3, or when explicitly requested ("just the slides", "just do phase 12", "just the deck").

Generate a Google Slides territory review deck from the FY27 CHATEE template, populated with account data from the intelligence brief and Salesforce.

**If running Phase 12 standalone** (user said "just the slides"/"just the deck"/"just do phase 12"): Search Google Drive for the existing Intelligence Brief document (`fullText contains 'ACCOUNT_NAME' and fullText contains 'Intelligence Brief'`), read its content, and use that as the data source instead of running Phases 0-5.

**Template ID**: `1U2xTfGLOry-VL8HWJuAi7BnUWRps4kQE4fB859KOvUo` (38 slides, 5 account sections)
**Rule**: NEVER modify the template — always copy it first.
**gslides_builder.py location**: `~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-slides-creator/resources/gslides_builder.py`

**Step 12.1 - Copy the template**

```bash
python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-slides-creator/resources/gslides_builder.py copy-presentation \
  --pres-id "1U2xTfGLOry-VL8HWJuAi7BnUWRps4kQE4fB859KOvUo" \
  --title "FY27 Territory Review - ACCOUNT_NAME"
```

Save the returned presentation ID as `NEW_PRES_ID`.

**Step 12.2 - Delete extra account sections (keep only slides 0-9)**

The template has 38 slides: title (1) + 5 account sections. Keep only the title slide and first account section (10 slides). Delete all slides after index 9.

```bash
# Get all slide IDs from the copy
python3 .../gslides_builder.py get-slide-ids --pres-id "NEW_PRES_ID"
```

Then delete slides at indices 10-37 using a single `batch_update` call with multiple `deleteObject` requests. This is more robust than hardcoding IDs since they survive copy.

```python
import sys
sys.path.insert(0, "~/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-slides-creator/resources")
import gslides_builder as gs

slide_ids = gs.get_slide_ids("NEW_PRES_ID")
# Delete all slides after index 9 (sections 2-5)
delete_requests = [{"deleteObject": {"objectId": sid}} for sid in slide_ids[10:]]
if delete_requests:
    gs.batch_update("NEW_PRES_ID", delete_requests)
```

After deletion, verify 10 slides remain: `gs.get_slide_ids("NEW_PRES_ID")`

**Step 12.3 - Update title slide (Slide 1, index 0)**

Use `replace_all_text()` to replace the template title:

```bash
python3 .../gslides_builder.py replace-all-text \
  --pres-id "NEW_PRES_ID" \
  --find "FY27 CHATEE" \
  --replace "FY27 Territory Review - ACCOUNT_NAME" \
  --match-case
```

**Step 12.4 - Update SA name divider (Slide 2, index 1)**

The divider slide contains the SA name (default: "Laurie"). Replace with the account's SA:

```bash
python3 .../gslides_builder.py replace-all-text \
  --pres-id "NEW_PRES_ID" \
  --find "Laurie" \
  --replace "SA_FULL_NAME" \
  --match-case
```

The SA name comes from `Account.Last_SA_Engaged__c` or the user's name (Laurent Prat).

**Step 12.5 - Populate strategy slides (Slides 3-5, indices 2-4)**

These slides contain shapes with free-form text. Use `get_presentation()` to discover shape IDs on each slide, then `replace_shape_text()` to update each shape.

**Discovery pattern** (run once to map shapes):
```python
pres = gs.get_presentation("NEW_PRES_ID")
for slide in pres['slides'][2:5]:  # slides 3-5 (indices 2-4)
    page_id = slide['objectId']
    print(f"\n=== Slide: {page_id} ===")
    for elem in slide.get('pageElements', []):
        obj_id = elem['objectId']
        if 'shape' in elem and 'text' in elem['shape']:
            text = ''.join(
                run.get('textRun', {}).get('content', '')
                for el in elem['shape']['text'].get('textElements', [])
                for run in [el] if 'textRun' in el
            ).strip()
            print(f"  Shape {obj_id}: '{text[:80]}...' " if len(text) > 80 else f"  Shape {obj_id}: '{text}'")
```

**Slide 3 - Immediate Priorities** (index 2, ~9 shapes):

| Shape Purpose | Data Source from Intelligence Brief |
|---|---|
| Strategy title | Brief § Growth Strategy Near-Term (1-2 sentence summary) |
| Exec Relationship column content | Brief § Stakeholders + Relationship Strengths |
| LoB Mindshare column content | Brief § Growth Strategy + LOB Whitespace |
| Champions column content | Brief § Key Stakeholders (Champions) |
| Bottom text area | Brief § Risks/Asks |

Keep column headers ("Exec Relationship Building", "LoB Mindshare Wins", "Champions Fostering") as-is. Only update the content shapes below them.

**Slide 4 - Long-Term Data & AI Vision** (index 3, ~31 shapes - grid layout):

This slide has a grid with priorities × (objectives, plans, outcomes). Map from Brief § Strategic Priorities + Growth Strategy Long-Term:
- Priority names (3-4 priorities from Strategic Objectives)
- Objectives per priority (from `StrategicPriority__c` records)
- Plans per priority (from brief growth strategy)
- Business outcomes per priority (from brief consumption/value targets)

**Slide 5 - Horizontal Priorities** (index 4, ~12 shapes):

Map from Brief § Technology Landscape + Growth Strategy:
- Serverless adoption plan (current state + next steps)
- Lakebase opportunity (if applicable, else "Not applicable")
- Genie/AI BI opportunity (current adoption + expansion plan)

For each shape update, use:
```bash
python3 .../gslides_builder.py replace-shape-text \
  --pres-id "NEW_PRES_ID" \
  --shape-id "SHAPE_ID" \
  --text "New content from intelligence brief"
```

Or batch via Python for efficiency:
```python
requests = []
for shape_id, new_text in shape_updates.items():
    existing = gs.get_text_content("NEW_PRES_ID", shape_id)
    if existing:
        requests.append({"deleteText": {"objectId": shape_id, "textRange": {"type": "ALL"}}})
    requests.append({"insertText": {"objectId": shape_id, "text": new_text, "insertionIndex": 0}})
gs.batch_update("NEW_PRES_ID", requests)
```

**Step 12.6 - Populate data tables (Slides 6-10, indices 5-9)**

These slides contain tables pre-populated with template data. Must **clear cells first, then insert new data**. Use `get_presentation()` to discover table IDs:

```python
pres = gs.get_presentation("NEW_PRES_ID")
for slide in pres['slides'][5:10]:  # slides 6-10 (indices 5-9)
    page_id = slide['objectId']
    print(f"\n=== Slide: {page_id} ===")
    for elem in slide.get('pageElements', []):
        if 'table' in elem:
            rows = elem['table']['rows']
            cols = elem['table']['columns']
            print(f"  Table {elem['objectId']}: {rows}x{cols}")
```

**Cell clear + fill pattern** (for tables with existing content):

```python
requests = []
for row_idx, row_data in enumerate(table_data):
    for col_idx, cell_value in enumerate(row_data):
        # 1. Delete existing text
        requests.append({
            "deleteText": {
                "objectId": table_id,
                "cellLocation": {"rowIndex": row_idx, "columnIndex": col_idx},
                "textRange": {"type": "ALL"}
            }
        })
        # 2. Insert new text (skip empty cells)
        if cell_value:
            requests.append({
                "insertText": {
                    "objectId": table_id,
                    "cellLocation": {"rowIndex": row_idx, "columnIndex": col_idx},
                    "text": str(cell_value),
                    "insertionIndex": 0
                }
            })
gs.batch_update("NEW_PRES_ID", requests)
```

**Note**: `deleteText` on an already-empty cell may error. To be safe, first read cell content via `get_presentation()` and only issue `deleteText` for non-empty cells. Or wrap in try/except per batch.

**Slide 6 - Consumption Forecast** (index 5):
- Main table (2×11): Row 0 = headers (keep), Row 1 = quarterly consumption values
- Data source: Opportunity amounts aggregated by quarter, or Brief § Consumption Forecast
- Best case table (1×3): Upside scenario

**Slide 7 - Use-Case Pipeline** (index 6):
- Table (8×5): UCOs organized by go-live quarter
- Data source: `UseCase__c` records from Salesforce Phase 1, grouped by `DatabricksGoLiveQrtr__c`
- Include: UCO name, stage, estimated consumption, go-live quarter

**Slide 8 - Priority Use Cases** (index 7):
- Table (5×6): Top 5 UCOs with execution details
- Columns: Use Case, Stage, Skills Needed, Execution Plan, Funding, Go-Live
- Data source: Top UCOs by estimated consumption from Salesforce

**Slide 9 - Priority Commit Deals** (index 8):
- Table (5×6): Active opportunities with commit strategy
- Columns: Opportunity, Amount, Close Date, Stage, Commit Strategy, Risk
- Data source: Open Opportunities from Salesforce Phase 1

**Slide 10 - Acceleration Plan** (index 9):
- Table (9×3): Strategic initiatives mapped to outcomes
- Columns: Initiative, Expected Outcome, Dependencies/Timeline
- Data source: Brief § Growth Strategy + Strategic Objectives

**Step 12.7 - Share the presentation**

Share with databricks.com domain as writer:

```bash
TOKEN=$(gcloud auth print-access-token)
curl -s -X POST "https://www.googleapis.com/drive/v3/files/NEW_PRES_ID/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{"type": "domain", "role": "writer", "domain": "databricks.com"}'
```

**Step 12.8 - Return the presentation URL**

```
https://docs.google.com/presentation/d/NEW_PRES_ID/edit
```

Display the URL to the user and include it in the summary output.

**Data mapping summary**:

| Slide | Element | Source |
|---|---|---|
| 1 (Title) | Title text | Account name |
| 2 (Divider) | SA name | Account SA / user name |
| 3 (Immediate Priorities) | Strategy shapes | Brief § Growth Strategy Near-Term + Stakeholders |
| 4 (Long-Term Vision) | Grid shapes | Brief § Strategic Priorities + Growth Strategy Long-Term |
| 5 (Horizontal Priorities) | Product shapes | Brief § Technology Landscape + Product adoption |
| 6 (Consumption Forecast) | Tables | Opportunity amounts by quarter |
| 7 (Use-Case Pipeline) | Table | UCOs grouped by go-live quarter |
| 8 (Priority Use Cases) | Table | Top 5 UCOs with execution details |
| 9 (Priority Deals) | Table | Active opportunities with commit strategy |
| 10 (Acceleration Plan) | Table | Strategic objectives → initiatives |

## Parallelization Strategy

To maximize speed, use Agent subagents in parallel:
1. **Phase 0**: Verify AccountPlan (get Account.Id) — must complete first
2. **Main thread**: Salesforce queries Phase 1 (sequential, since each depends on Account ID)
3. **Agent 1**: Gmail email search + metadata extraction + full body reads of key emails — launch after Phase 0 (only needs account name)
4. **Agent 2**: Google Drive document search + content extraction from key docs — launch after Phase 0
5. **Agent 3**: Read remaining emails (older batch) — launch after Agent 1 returns message IDs

Launch Agents 1-2 in parallel immediately after Phase 0 completes. Do NOT wait for all Phase 1 queries.

After agents complete, append their findings to the Google Doc using Docs API `batchUpdate` (insertText at end of document).

## Output

**Scope 1** (Google Doc only):
- Google Doc URL shared with databricks.com domain
- Temp file cleaned up
- Summary of sources scanned and sections produced

**Scope 2** (adds Salesforce):
- Everything from scope 1, plus:
- Salesforce AccountPlan fully populated (20 fields)
- 3-5 Strategic Objectives created as `StrategicPriority__c` records
- Partner Landscape populated as `AccountPlanRelated__c` records (partners, contractors, competitors)
- Whitespace By LOB populated as `AccountPlanRelated__c` records (4-6 LOBs with workload status)
- Migration Plan populated as `AccountPlanRelated__c` records (migration workstreams with timelines)
- TAP Map populated: EB Champion records (UI tabs) + BU+1 records (detailed whitespace)

**Scope 3** (adds Slides):
- Everything from scope 2, plus:
- Google Slides territory review deck (10 slides) shared with databricks.com domain

## Tips

- Use the customer's email domain (e.g., `msc.com`) in Gmail searches alongside the account name
- Filter out Outreach/automated emails in Salesforce tasks to find meaningful activities
- Focus Gmail full-body reads on strategic discussions, technical guidance, and meeting follow-ups (skip calendar RSVPs and notifications)
- Look for departures of key contacts - these are critical risks
- Cross-reference Salesforce contacts with email activity to identify true champions vs. passive contacts
- If no UCOs exist in Salesforce, look for use case information in Google Drive documents or email threads
- **AccountPlan API version**: Must use `v66.0` — earlier versions return 404 for the AccountPlan sObject
- **AccountPlan updates**: Use REST API PATCH (not `sf data update record`) for multi-line text fields with special characters
- **Strategic Objectives**: The `AccountPlan__c` lookup is set at creation time and becomes read-only — ensure correct AccountPlan ID before creating
- **Contact IDs for objectives**: Query Contacts by account + name patterns to get IDs for `PrimaryCustomerExec__c` — match to champions, CxOs, and technical leaders identified in the intelligence brief
- **Status picklist values**: `Not started`, `In progress`, `Complete`, `Blocked`
- **Strategic Objective naming**: Use outcome-driven titles (e.g., "Drive 277% Consumption Growth") not activity-based ("Migrate databases")
- **Partner Landscape `Name`**: Auto-generated (read-only) — do NOT include in POST payload or it will error
- **Partner Landscape RecordType**: Must set `RecordTypeId` to Partner Landscape ID (`012Vp000002oeCRIAY`), not the default Master RT
- **Sentiment mapping**: Green = force multiplier (activate), Amber = monitor/re-engage, Red = competitive threat or blocked
- **Competitors as partners**: Create a Partner Landscape record for each competitor with `CompetitorProducts__c` set and workload fields showing `Lost/Competitor` where they have presence
- **Account_Partner__c is prerequisite**: Partner Landscape records only display Partner Name when `AccountPartner__c` is populated — create `Account_Partner__c` records FIRST (Step 8.6), then link them
- **Account_Partner__c.Account__c**: Createable but NOT updateable — must be set in POST payload at creation time
- **Account_Partner__c.Partner_Account__c is required**: A Salesforce trigger (`AccountPartnerTrigger`) throws `NullPointerException` if `Partner_Account__c` is null — the partner must exist as an Account in Salesforce
- **Partner Engagement Stage**: Use exact picklist values (e.g., `3 - Engaged with C&SI Partner in Delivery (Land)`) — abbreviated forms fail with `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST`
- **Whitespace By LOB RecordType**: `012Vp000002oeCUIAY` — different from Partner Landscape RT
- **LOBName__c**: Free text string (255 chars) — use descriptive names like "Front Office Technology - Houston"
- **IncumbentTools__c / CompetitorProducts__c**: Semicolon-separated multipicklist values from a fixed list — check describe for valid values
- **DatabricksGoLiveQrtr__c**: Restricted picklist `FY'27 Q1` through `FY'28 Q1` — use exact format with smart quotes
- **AccountPartner__c reference**: Only set this if a formal `Account_Partner__c` record exists (query first). Staff aug contractors typically don't have one
- **TAP Architecture Powerbase (BU+1) RecordType**: `012Vp000002oeCTIAY` — uses `BuPlusOneName__c` (not `Name`), `Category__c`, `EstimatedTAM__c`, `EstimatedDatabricks__c`, `WhitespaceNotes__c`, `NextStepsActions__c`
- **BU+1 Category__c picklist**: Values are RecordType-specific! Valid for BU+1: `Ingest & Transform`, `ML Stack`, `Data Warehouse`, `Gen AI`, `Data Sharing`, `Data Governance`, `Cloud Data`, `Data Analytics`, `Data Science & AI`, `Data Management & Storage`, `Streaming & Ingestion`. Query via `/ui-api/object-info/AccountPlanRelated__c/picklist-values/{RT_ID}` to get RT-specific values
- **BU+1 field mapping**: `BuPlusOneName__c` = display name, `Category__c` = product area, `EstimatedTAM__c` = currency, `EstimatedDatabricks__c` = percent (0-100), `IncumbentTechnology__c` = free text, `IncumbentTools__c` = multipicklist, `DepartmentsLOBsLeveraging__c` = free text, `RelatedContact__c` = Contact lookup, `RelatedStrategicPriority__c` = Strategic Objective lookup
- **BU+1 Category mapping from product areas**: Data Engineering → `Ingest & Transform`, Agent Bricks/ML → `Gen AI` or `ML Stack`, AI/BI → `Data Analytics`, Data Warehouse → `Data Warehouse`, Unity Catalog → `Data Governance`
- **TAP MAP UI IS DRIVEN BY EB CHAMPION RECORDS, NOT BU+1**: The TAP (TAM, Architecture, Powerbase) Map visualization in the Account Plan UI renders from the **EB Champion** RecordType (`012Vp000002oeCPIAY`), NOT Whitespace By BU+1. BU+1 records store detailed whitespace data but do NOT appear in the TAP Map tabs. You MUST create EB Champion records to populate the TAP Map.
- **EB Champion Category__c picklist**: Fixed tab values: `Ingest & Transform`, `ML Stack`, `Data Warehouse`, `Data Sharing`, `Data Governance`, `GenAI Stack`, `Data Format`, `Lakebase / OLTP`. These match the TAP Map UI tabs exactly. Note `GenAI Stack` (not `Gen AI` which is the BU+1 value).
- **EB Champion field mapping**: `Category__c` = determines which TAP tab, `RelatedContact__c` = EB/Champion (Contact lookup), `EstimatedTAM__c` = Estimated TAM (currency), `EstimatedDatabricks__c` = DBRX % of TAM (percent 0-100), `IncumbentTools__c` = Incumbent Tools (multipicklist, semicolon-separated)
- **EB Champion creation pattern**: One record per relevant Category tab. Leave irrelevant tabs empty (e.g., skip `Data Format` and `Lakebase / OLTP` if customer doesn't use those). Fields are minimal — no Notes/NextSteps/Details on this RT.
- **TAP Map: two-layer approach**: Create EB Champion records for TAP Map UI visibility (TAM, champion, incumbent per tab), AND BU+1 records for deeper whitespace detail (notes, next steps, departments, strategic priorities). Both use `Category__c` but with different valid picklist values per RT.
- **sf CLI stderr corrupts JSON**: Always use `2>/dev/null` on `sf data query` commands. The CLI prints `Warning: @salesforce/cli update available` to stderr which mixes into JSON output.
- **sf sobject describe is unreliable**: Piping `sf sobject describe --json` into Python fails because stderr warnings corrupt the JSON. Use REST API describe instead (urllib.request to `/services/data/v66.0/sobjects/OBJECT/describe`).
- **UseCase__c fields**: Many documented fields don't exist. Only `Id`, `Name`, `Use_Case_Description__c`, `Demand_Plan_Next_Steps__c`, `CreatedDate`, `LastModifiedDate` work reliably.
- **SOQL NOT syntax**: Must wrap in parentheses: `AND (NOT Subject LIKE '%Outreach%')`. Without parens: "unexpected token: 'NOT'".
- **Contact name accents**: SOQL exact match fails for accented names (e.g., `René`). Use `LIKE '%LastName%'` pattern instead.
- **Temp file collision**: Use account-specific filenames (`/tmp/account_brief_ACCOUNTNAME.md`) and clean up after Google Doc creation.
- **markdown_tables_to_gdocs.py "no tables found"**: This is benign — `markdown_to_gdocs.py` often handles tables during initial creation.

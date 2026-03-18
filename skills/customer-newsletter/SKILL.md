---
name: customer-newsletter
description: Generate personalized Databricks newsletters for customers. Queries Salesforce for account/UCO context, searches for relevant public Databricks content, generates a professional HTML email, and creates a Gmail draft ready to send.
user_invocable: true
---

# Customer Newsletter

Generate a personalized Databricks newsletter email for a customer account by combining Salesforce context with curated public Databricks content.

## CRITICAL RULE: All Links Must Be Verified

**EVERY link in the newsletter MUST be curl-verified as HTTP 200 before inclusion.** No exceptions. Databricks blog URLs frequently 404. Never guess or fabricate URLs. Always batch-verify with:
```bash
for url in <all_candidate_urls>; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")
  echo "$code - $url"
done
```
Only include links returning 200. If a link fails, find a replacement from the seed list or another verified source. **Do NOT include any link that has not been verified in the current session.**

## Trigger

When the user asks to create a customer newsletter, Databricks update email, or account newsletter for a specific account name.

## Input

The user provides:
1. **Account name** (required) - e.g., "SITA", "Nestle", "MSC CARGO"
2. **--to email** (optional) - recipient email address for the draft
3. **--from name,email** (optional) - sender name and email for CTA/footer. If omitted, defaults to the Account's AE (Owner) from Salesforce.
4. **--since YYYY-MM-DD** (optional) - only include content published after this date. Defaults to 3 months ago (quarterly cadence). Use `--since 2025-01-01` to widen the search window.
5. **--reset** (optional) - clear the send history for this account, allowing previously sent links to be reused. Use when onboarding a new recipient or replaying from scratch.
6. **--date YYYY-MM-DD** (optional) - generate the newsletter as if it were that date (for replays/backfills). Affects the "Month Year" in the header and the `--since` default window.
7. **--domain "topic"** (optional) - Focus the newsletter on a specific domain (e.g., "Predictive Maintenance in Cargo", "Real-time Fraud Detection", "Customer 360"). When set, content curation shifts from general UCO-based matching to domain-focused research including tutorials, demos, articles, reference architectures, and case studies. Target 6-8 links grouped by category instead of the standard 4-6.

**Inline help**: If the user passes `help`, `--help`, or `?`, display:

```
Usage: /customer-newsletter <Account Name> [--to contact@email.com] [--from "Name,email"] [--since YYYY-MM-DD] [--reset] [--date YYYY-MM-DD] [--domain "topic"]

Generates a personalized Databricks newsletter for a customer:
  1. Queries Salesforce for account info and active Use Cases
  2. Searches web for relevant Databricks content (blogs, docs, case studies)
  3. Creates a professional HTML email with curated links
  4. Saves as Gmail draft ready to send
  5. Records sent links to avoid repeats in future newsletters

The sender (CTA button + footer) defaults to the Account's AE from Salesforce.
Override with --from to use a different sender.

Options:
  --since YYYY-MM-DD   Only include content after this date (default: 3 months ago)
  --reset              Clear send history for this account (fresh start)
  --date YYYY-MM-DD    Generate as if today were this date (for replays)
  --domain "topic"     Focus newsletter on a specific domain topic (6-8 links grouped by category)

Examples:
  /customer-newsletter SITA
  /customer-newsletter SITA --to john.doe@sita.aero
  /customer-newsletter SITA --to john@sita.aero --from "Laurent Prat,laurent.prat@databricks.com"
  /customer-newsletter SITA --since 2025-06-01              # wider content window
  /customer-newsletter SITA --reset --to john@sita.aero     # fresh start, no dedup
  /customer-newsletter SITA --date 2025-12-01               # replay Q4 2025 newsletter
  /customer-newsletter SITA --domain "Predictive Maintenance in Aviation"
  /customer-newsletter "MSC CARGO" --domain "Supply Chain Optimization" --to john@msc.com
  /customer-newsletter help
```

## Workflow

### Phase 1: Collect Customer Context from Salesforce

Use the Salesforce CLI (`/opt/homebrew/bin/sf`) to query account and UCO data.

**Step 1a: Get Account Info (including AE)**
```bash
/opt/homebrew/bin/sf data query --query "SELECT Id, Name, Industry, Owner.Name, Owner.Email FROM Account WHERE Name LIKE '<account_name>%'" --json
```
Use prefix match (`Name LIKE 'SITA%'`) not contains match (`%SITA%`) to avoid too many results.

**Selecting the right account when multiple matches are returned:**
- Prefer accounts with "Main account" in the name (e.g., "Swatch Group - Main account")
- If no "Main account" variant, prefer the one whose `Industry` is non-null
- If still ambiguous, query UCOs for each candidate and pick the one with active UCOs (U2-U6)
- Ignore unrelated accounts that happen to share a prefix (e.g., "swatchbook" vs "Swatch Group")

The `Owner.Name` and `Owner.Email` fields give us the Account Executive (AE). Use these as the sender in the CTA button and footer unless `--from` was explicitly provided.

**Step 1b: Get Active Use Cases (U2-U6)**
```bash
/opt/homebrew/bin/sf data query --query "SELECT Id, Name, Stages__c, Use_Case_Description__c, Implementation_Status__c, Demand_Plan_Next_Steps__c FROM UseCase__c WHERE Account__c = '<account_id>' AND Stages__c IN ('U2','U3','U4','U5','U6')" --json
```

**Note on field names:** The Account and UseCase__c objects do NOT have `Products__c`, `Workloads__c`, `Platform__c`, `Cloud_Type__c`, `ACV__c`, or `ARR__c` fields. Extract workload/product context from the UCO `Name` and `Use_Case_Description__c` fields instead.

Extract from results:
- Industry (from Account)
- Products and workloads (inferred from UCO names and descriptions, e.g., Unity Catalog, Delta Lake, MLflow, Streaming)
- UCO stages (to tailor content maturity: U2-U3 = evaluating, U4-U5 = onboarding, U6 = production)

### Phase 1b: Load Send History from Google Drive (Deduplication)

Previously sent newsletters are stored in a shared Google Drive folder. Each newsletter HTML file contains a `<!-- newsletter-meta -->` comment with the full list of links used. This is the **source of truth** for deduplication — no local history files.

**Drive structure:** `SA Customer Newsletters / <Account Name> /` in Google Drive (shared with databricks.com domain as writer, so any SA can generate newsletters and dedup across the team).

Each customer gets its own subfolder (e.g., `SA Customer Newsletters/SITA/`, `SA Customer Newsletters/MSC Cargo/`). This keeps newsletters organized per account even if the AE changes.

**Known Drive folder ID:** The parent folder "SA Customer Newsletters" has ID `1AdcDxj-gA55j1ihLt0Ohbjyd3WtpISbN`. Use this directly to skip the search step when possible.

**Steps:**
1. Search Google Drive for the parent newsletters folder (or use known ID `1AdcDxj-gA55j1ihLt0Ohbjyd3WtpISbN`):
```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -s "https://www.googleapis.com/drive/v3/files?q=name%3D'SA+Customer+Newsletters'+and+mimeType%3D'application/vnd.google-apps.folder'+and+trashed%3Dfalse&fields=files(id,name)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```
If the folder doesn't exist, create it (see Phase 4b).

2. Find or create the customer subfolder:
```bash
PARENT_FOLDER="<parent_folder_id>"
ACCOUNT_NAME="<Account Name>"
# Search for existing customer subfolder
curl -s "https://www.googleapis.com/drive/v3/files?q='${PARENT_FOLDER}'+in+parents+and+name%3D'${ACCOUNT_NAME}'+and+mimeType%3D'application/vnd.google-apps.folder'+and+trashed%3Dfalse&fields=files(id,name)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```
If not found, create it as a child of the parent folder.

3. List all newsletter files in the customer subfolder:
```bash
CUSTOMER_FOLDER="<customer_folder_id>"
curl -s "https://www.googleapis.com/drive/v3/files?q='${CUSTOMER_FOLDER}'+in+parents+and+trashed%3Dfalse&fields=files(id,name,createdTime)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

4. For each file found, download and extract the `<!-- newsletter-meta -->` comment:
```bash
FILE_CONTENT=$(curl -s "https://www.googleapis.com/drive/v3/files/${FILE_ID}?alt=media" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng")
# Extract links from metadata comment
echo "$FILE_CONTENT" | grep -o '<!-- newsletter-meta:.*-->' | head -1
```

4. Parse the `links=` field from each metadata comment to build the **previously sent links set**
5. If `--reset` was passed, skip loading history (treat as empty set)
6. Pass the previously sent links set to Phase 2 for exclusion

**Note:** The newsletter HTML file IS the history record. No separate JSON files needed. This makes history shareable across SAs and machines.

### Phase 2: Web Search for Relevant Databricks Content

Based on the customer context from Phase 1, curate 4-6 relevant public Databricks links.

**IMPORTANT - Deduplication:** Exclude any URL found in the previously sent links set (from Phase 1b). If a candidate link was already sent in a previous newsletter for this account, skip it and find a different one. This ensures each quarterly newsletter has fresh content.

**Strategy: Try WebSearch first, fall back to known URLs if unavailable.**

**Date window:** Determine the content search window:
- If `--since` provided: use that date as the start
- If `--date` provided: default to 3 months before that date
- Otherwise: default to 3 months before today
- Include the year in all WebSearch queries to bias toward recent results (e.g., "databricks unity catalog 2026")

**Step A: Try WebSearch** for content matching customer products/industry/workloads.

**When `--domain` is set:** Replace UCO-based search strategy with domain-focused searches across 6 content categories. Run WebSearch queries targeting each category:

| Category | Search query pattern | Section title in email |
|----------|---------------------|----------------------|
| Reference Architecture | `databricks "<domain>" reference architecture` | Reference Architectures |
| Tutorials & Guides | `databricks "<domain>" tutorial OR guide OR how-to` | Tutorials & How-To Guides |
| Public Demos & Notebooks | `databricks "<domain>" demo OR notebook OR example site:github.com OR site:databricks.com` | Demos & Examples |
| Blog Articles | `databricks "<domain>" blog site:databricks.com/blog` | Articles & Insights |
| Case Studies | `databricks "<domain>" case study OR customer story site:databricks.com` | Customer Stories |
| Documentation | `databricks "<domain>" site:docs.databricks.com` | Documentation |

- Target **6-8 links** (more than the standard 4-6, since domain mode is comprehensive)
- Each category should have at least 1 link if available
- All links still go through curl verification
- Still exclude previously sent links (dedup from Drive history)
- Still apply `--since` date window where relevant

**When `--domain` is NOT set (standard mode):**
- Product updates matching their stack (e.g., "databricks streaming best practices 2026", "databricks unity catalog 2026")
- Industry content for their vertical (e.g., "databricks manufacturing logistics", "databricks aviation")
- Best practices matching UCO stages (U2-U3 = getting started; U4-U5 = architecture guides; U6 = optimization)
- **Exclude previously sent links** (from Phase 1b history). If a search result URL is in the sent set, skip it.

**Step B: If WebSearch fails**, use known-good Databricks URLs from this seed list (all verified 200 as of Mar 2026):
```
# Product pages
https://www.databricks.com/product/machine-learning
https://www.databricks.com/product/ai-bi
https://www.databricks.com/product/unity-catalog
https://www.databricks.com/product/delta-lake-on-databricks
https://www.databricks.com/product/data-intelligence-platform
https://www.databricks.com/product/delta-live-tables
https://www.databricks.com/product/lakebase

# Blog posts
https://www.databricks.com/blog/streaming-production-collected-best-practices
https://www.databricks.com/blog/open-sourcing-unity-catalog
https://www.databricks.com/blog/what-is-a-data-intelligence-platform

# Documentation
https://docs.databricks.com/en/generative-ai/retrieval-augmented-generation.html
https://docs.databricks.com/en/generative-ai/build-genai-apps.html
https://docs.databricks.com/en/data-governance/unity-catalog/index.html
https://docs.databricks.com/en/delta-live-tables/index.html
https://docs.databricks.com/en/structured-streaming/index.html
https://docs.databricks.com/en/machine-learning/index.html
https://docs.databricks.com/en/delta/index.html
https://docs.databricks.com/en/release-notes/index.html

# Industry solutions
https://www.databricks.com/solutions/industries/manufacturing
https://www.databricks.com/solutions/industries/communications
```
**WARNING:** Even seed list URLs can go stale. Always curl-verify before including, even from this list.
Pick 4-6 links from this list (or from WebSearch results) that best match the customer's workloads.

**CRITICAL - Link Validation:** Every link MUST be verified with curl before including:
```bash
curl -s -o /dev/null -w "%{http_code}" -L "<url>"
```
Only include links returning HTTP 200. Batch-verify all candidates in a single for-loop. Do NOT guess or fabricate Databricks blog URLs - they frequently 404.

For each link, capture:
- Title
- URL (verified 200)
- 1-sentence description tailored to the customer's context
- Category: "For Your [Workload]", "Industry Spotlight", or "What's New"

### Phase 2b: Find Upcoming Databricks Events

Search for upcoming Databricks events to include in a dedicated "Upcoming Events" section.

**Known event pages (verify with curl before using):**
- `https://www.databricks.com/dataaisummit` - Data + AI Summit (annual flagship, usually June)
- `https://www.databricks.com/events` - All upcoming events listing
- `https://www.databricks.com/ai-days` - AI Days (free regional events in 38+ cities)

**IMPORTANT:** Always include both Data + AI Summit AND AI Days in the events section. AI Days are free, regional events that are highly accessible for European customers. Mention cities geographically relevant to the customer (e.g., Geneva/Milan for Swiss accounts, Paris for French accounts).

**Steps:**
1. Fetch `https://www.databricks.com/events` with WebFetch to find upcoming events
2. Also check `https://www.databricks.com/dataaisummit` and `https://www.databricks.com/ai-days` for flagship events
3. For each relevant event, extract: name, date, location (or "Virtual"), registration URL, and 2-3 agenda highlights or keynote topics
4. Prioritize events geographically relevant to the customer (check Account Industry/location context)
5. Include 1-3 events max

**When `--domain` is set**, additionally search for:
- Domain-specific conferences/meetups: `"<domain>" conference OR summit OR meetup 2026`
- Databricks events with domain-relevant sessions: check if Data+AI Summit or AI Days have tracks matching the domain
- Industry events where Databricks is presenting on the domain topic
Prioritize events with sessions/tracks relevant to the domain over generic Databricks events.

**For each event, capture:**
- Event name
- Date and location
- Registration URL (verified 200)
- 2-3 agenda highlights that would resonate with the customer's workloads (e.g., if customer does ML, highlight ML/AI sessions)

### Phase 3: Generate Newsletter HTML Email

Create a professional HTML email with inline CSS (email-client safe). Use Databricks brand colors.

**Design specifications:**
- Primary color: `#FF3621` (Databricks red/orange)
- Secondary: `#1B3139` (dark teal)
- Background: `#F5F5F5`
- Card background: `#FFFFFF`
- Font: Arial, Helvetica, sans-serif
- Mobile-friendly: max-width 600px, responsive padding

**HTML Template Structure:**

```html
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#F5F5F5;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F5F5;">
<tr><td align="center" style="padding:20px 10px;">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

  <!-- Header -->
  <!-- newsletter-meta: account={{ACCOUNT_NAME}} domain={{DOMAIN_OR_EMPTY}} period={{SINCE_DATE}}:{{EFFECTIVE_DATE}} generated={{TODAY}} links={{URL1}}|{{URL2}}|{{URL3}}|... -->
  <!-- When --domain is set, include domain={{DOMAIN}} in the meta comment. When not set, omit the domain field entirely. -->
  <tr><td style="background-color:#1B3139;padding:30px 40px;border-radius:8px 8px 0 0;">
    <!-- Standard mode: -->
    <h1 style="color:#FFFFFF;margin:0;font-size:24px;">Your Databricks Update</h1>
    <p style="color:#FF3621;margin:5px 0 0;font-size:14px;">{{QUARTER_LABEL}} | Curated for {{ACCOUNT_NAME}}</p>
    <!-- Domain mode (when --domain is set, use these instead): -->
    <!-- <h1 style="color:#FFFFFF;margin:0;font-size:24px;">{{DOMAIN}} on Databricks</h1> -->
    <!-- <p style="color:#FF3621;margin:5px 0 0;font-size:14px;">{{QUARTER_LABEL}} | {{DOMAIN}} on Databricks — Curated for {{ACCOUNT_NAME}}</p> -->
  </td></tr>

  <!-- Personalized Intro -->
  <tr><td style="background-color:#FFFFFF;padding:30px 40px;">
    <p style="color:#333333;font-size:15px;line-height:1.6;margin:0;">
      Hi there,<br><br>
      {{PERSONALIZED_INTRO}}
    </p>
  </td></tr>

  <!-- Content Section (repeat per category) -->
  <tr><td style="background-color:#FFFFFF;padding:10px 40px 20px;">
    <h2 style="color:#1B3139;font-size:18px;margin:0 0 15px;border-bottom:2px solid #FF3621;padding-bottom:8px;">
      {{SECTION_TITLE}}
    </h2>

    <!-- Content Card (repeat per item) -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:15px;">
    <tr><td style="background-color:#F9F9F9;padding:15px 20px;border-radius:6px;border-left:3px solid #FF3621;">
      <a href="{{LINK_URL}}" style="color:#1B3139;font-size:15px;font-weight:bold;text-decoration:none;">{{LINK_TITLE}}</a>
      <p style="color:#666666;font-size:13px;margin:5px 0 0;line-height:1.5;">{{LINK_DESCRIPTION}}</p>
    </td></tr>
    </table>
  </td></tr>

  <!-- Upcoming Events Section -->
  <tr><td style="background-color:#FFFFFF;padding:10px 40px 20px;">
    <h2 style="color:#1B3139;font-size:18px;margin:0 0 15px;border-bottom:2px solid #FF3621;padding-bottom:8px;">
      Upcoming Events
    </h2>

    <!-- Event Card (repeat per event, 1-3 max) -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:15px;">
    <tr><td style="background-color:#1B3139;padding:20px;border-radius:6px;">
      <p style="color:#FF3621;font-size:12px;font-weight:bold;margin:0 0 5px;text-transform:uppercase;">{{EVENT_DATE}} &bull; {{EVENT_LOCATION}}</p>
      <a href="{{EVENT_URL}}" style="color:#FFFFFF;font-size:16px;font-weight:bold;text-decoration:none;">{{EVENT_NAME}}</a>
      <p style="color:#CCCCCC;font-size:13px;margin:8px 0 12px;line-height:1.5;">{{EVENT_HIGHLIGHTS}}</p>
      <a href="{{EVENT_URL}}" style="background-color:#FF3621;color:#FFFFFF;padding:8px 20px;text-decoration:none;border-radius:4px;font-size:13px;font-weight:bold;display:inline-block;">Register Now</a>
    </td></tr>
    </table>
  </td></tr>

  <!-- CTA -->
  <tr><td style="background-color:#FFFFFF;padding:20px 40px 30px;text-align:center;">
    <p style="color:#333333;font-size:14px;margin:0 0 15px;">Want to dive deeper into any of these topics?</p>
    <a href="mailto:{{SENDER_EMAIL}}" style="background-color:#FF3621;color:#FFFFFF;padding:12px 30px;text-decoration:none;border-radius:5px;font-size:14px;font-weight:bold;display:inline-block;">Let's Connect</a>
  </td></tr>

  <!-- Footer -->
  <tr><td style="background-color:#1B3139;padding:20px 40px;border-radius:0 0 8px 8px;text-align:center;">
    <p style="color:#AAAAAA;font-size:12px;margin:0;">
      {{SENDER_NAME}} | Databricks<br>
      <a href="mailto:{{SENDER_EMAIL}}" style="color:#FF3621;text-decoration:none;">{{SENDER_EMAIL}}</a>
    </p>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>
```

**Quarter label:** Use a human-readable label for the period, e.g.:
- `Q1 2026` (Jan-Mar), `Q2 2026` (Apr-Jun), etc.
- Or `March 2026` if the period doesn't align to a clean quarter
- Derive from the effective date

**Newsletter metadata comment:** The `<!-- newsletter-meta: ... -->` HTML comment embeds machine-readable metadata directly in the newsletter file. Fields:
- `account` - Account name
- `period` - Content window as `SINCE_DATE:EFFECTIVE_DATE`
- `generated` - Generation date
- `links` - Pipe-separated (`|`) list of all content URLs included (without UTM params)

This is the **source of truth** for deduplication. When scanning previous newsletters on Google Drive, parse this comment to extract previously used links.

**Personalized intro guidelines:**
- Reference 1-2 of their active use cases or workloads naturally
- Keep it to 2-3 sentences max
- Tone: helpful, professional, not salesy
- Example: "With your team ramping up on Unity Catalog and expanding your streaming workloads, I thought you'd find these recent updates particularly relevant."

**When `--domain` is set:**
- Reference the domain topic + customer context in the intro. E.g., "As you explore Predictive Maintenance capabilities for your cargo operations, here's a curated collection of resources showing what's possible on the Databricks Data Intelligence Platform."
- Group content links by category (Reference Architectures, Tutorials & How-To Guides, Demos & Examples, Articles & Insights, Customer Stories, Documentation) instead of the generic "For Your [Workload]" / "Industry Spotlight" / "What's New" grouping
- Use the category names from the Phase 2 search table as section titles

**Sender resolution (for CTA button and footer):**
1. If `--from "Name,email"` was provided, use that
2. Otherwise, use the Account's AE from Salesforce: `Owner.Name` and `Owner.Email` queried in Phase 1
3. Replace `{{SENDER_NAME}}` and `{{SENDER_EMAIL}}` in the CTA and footer with the resolved values

**IMPORTANT:** The default sender is always the **AE** (Account Executive / Account Owner), NOT the SA. The newsletter is sent on behalf of the AE to strengthen the AE-customer relationship. The SA only appears as sender if explicitly overridden with `--from`.

**UTM parameters:** Add to all links for future tracking:
`?utm_source=sa_newsletter&utm_medium=email&utm_campaign={{account_name_lowercase}}`

### Phase 4: Create Gmail Draft

**Always** write HTML to a temp file first (the content is too long for inline args), then pass via shell variable:
```bash
# Step 1: Write HTML to temp file using the Write tool
# Write to /tmp/newsletter_<account>.html

# Step 2: Create draft from variable
HTML_CONTENT=$(cat /tmp/newsletter_<account>.html) && python3 /Users/laurent.prat/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/gmail/resources/gmail_builder.py \
  create-draft \
  --to "{{RECIPIENT_EMAIL}}" \
  --subject "Your Databricks Update - {{MONTH}} {{YEAR}}" \  # Standard mode
  # Domain mode: --subject "{{DOMAIN}} on Databricks — Resources for {{ACCOUNT_NAME}}" \
  --html "$HTML_CONTENT"
```

- If `--to` was provided by the user, use that email address
- If no `--to` was provided, use the **AE email** (Owner.Email from Salesforce) as `--to`. The user can change the recipient in Gmail before sending. Do NOT use placeholder strings like "REPLACE_WITH_RECIPIENT" — `gmail_builder.py` validates the To header and will reject invalid emails with a 400 error.
- `gmail_builder.py create-draft` does NOT support `--html-file`. Always use `--html` with content as a string variable.
- To delete and replace an existing draft: `gmail_builder.py delete-draft --draft-id "<id>"`

### Phase 4b: Upload Newsletter to Google Drive

After the Gmail draft is created successfully, upload the newsletter HTML to the shared Google Drive folder. This serves as both the archive AND the deduplication source.

**Step 1: Ensure the Drive folder structure exists**
```bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT="gcp-sandbox-field-eng"

# Search for parent folder
FOLDER_SEARCH=$(curl -s "https://www.googleapis.com/drive/v3/files?q=name%3D'SA+Customer+Newsletters'+and+mimeType%3D'application/vnd.google-apps.folder'+and+trashed%3Dfalse&fields=files(id,name)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT")

PARENT_FOLDER=$(echo "$FOLDER_SEARCH" | jq -r '.files[0].id // empty')

# Create parent folder if it doesn't exist
if [ -z "$PARENT_FOLDER" ]; then
  PARENT_FOLDER=$(curl -s -X POST "https://www.googleapis.com/drive/v3/files" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $QUOTA_PROJECT" \
    -H "Content-Type: application/json" \
    -d '{"name": "SA Customer Newsletters", "mimeType": "application/vnd.google-apps.folder"}' | jq -r '.id')

  # Share with databricks.com domain as writer
  curl -s -X POST "https://www.googleapis.com/drive/v3/files/${PARENT_FOLDER}/permissions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $QUOTA_PROJECT" \
    -H "Content-Type: application/json" \
    -d '{"type": "domain", "role": "writer", "domain": "databricks.com"}'
fi

# Find or create customer subfolder
ACCOUNT_NAME="<Account Name>"
SUBFOLDER_SEARCH=$(curl -s "https://www.googleapis.com/drive/v3/files?q='${PARENT_FOLDER}'+in+parents+and+name%3D'${ACCOUNT_NAME}'+and+mimeType%3D'application/vnd.google-apps.folder'+and+trashed%3Dfalse&fields=files(id,name)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT")

CUSTOMER_FOLDER=$(echo "$SUBFOLDER_SEARCH" | jq -r '.files[0].id // empty')

if [ -z "$CUSTOMER_FOLDER" ]; then
  CUSTOMER_FOLDER=$(curl -s -X POST "https://www.googleapis.com/drive/v3/files" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $QUOTA_PROJECT" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${ACCOUNT_NAME}\", \"mimeType\": \"application/vnd.google-apps.folder\", \"parents\": [\"${PARENT_FOLDER}\"]}" | jq -r '.id')
fi
```

**Step 2: Upload the newsletter HTML file to the customer subfolder**
```bash
# File naming: <account_lowercase>_<effective_date>.html
FILENAME="<account_lowercase>_<effective_date>.html"

# Upload using multipart upload
curl -s -X POST "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -F "metadata={\"name\": \"${FILENAME}\", \"parents\": [\"${CUSTOMER_FOLDER}\"]};type=application/json" \
  -F "file=@/tmp/newsletter_<account>.html;type=text/html"
```

File naming examples: `sita_2026-03-17.html`, `msc_cargo_2026-06-15.html`

**Important:** Upload to Drive regardless of whether the Gmail draft succeeded. The Drive archive serves as the deduplication source and should always be saved. If the draft failed, note this in the summary but still archive the newsletter.

### Phase 5: Summary

After creating the draft, report:
1. Account context found (industry, products, workloads)
2. Sender used (AE name from Salesforce or `--from` override)
3. Number of content items curated + links with categories
4. Events included with dates/locations
5. Gmail draft status (created / failed)
6. **Previously sent links excluded** (count, or "first send" if no history on Drive)
7. **Content window** (from `--since` date to effective date)
8. **Drive archive** - file name and link to the uploaded newsletter in `SA Customer Newsletters` folder
9. **Domain focus** (when `--domain` is set) - the domain topic used and how many links per category
10. Remind user to review the draft in Gmail before sending

## Notes

- All links must be publicly accessible and verified 200 (no internal Databricks links)
- Keep the newsletter concise: 4-6 content links + 1-3 events, no walls of text
- The email should be scannable in under 60 seconds
- Prefer recent content (last 3-6 months) over older posts
- If Salesforce query returns no UCOs, still generate using account-level info (industry)
- Event highlights should be tailored to the customer's workloads (e.g., ML sessions for ML customers)
- Prioritize geographically relevant events (European events for European customers, etc.)
- The greeting should use the recipient's first name (extracted from `--to` email or asked)

# UCO Onboarding Document Template

Standard template for U5 (Onboarding) stage Use Case documentation.

## Document Structure

The onboarding doc uses proper Google Docs formatting:
- **TITLE** style for document title
- **HEADING_1** for main sections
- **HEADING_2** for phase subsections
- **Bullet points** for list items
- **Bold** for key labels

## Template Content

```
[TITLE] Onboarding Plan: {UCO_NAME}

[HEADING_1] USE CASE OVERVIEW

Account: {ACCOUNT_NAME}
UCO Name: {UCO_NAME}
Stage: U5 - Onboarding
Target Live Date: {TARGET_DATE}
Implementation Strategy: {STRATEGY}

[HEADING_1] OBJECTIVE

{DESCRIPTION}

[HEADING_1] ONBOARDING MILESTONES

[HEADING_2] Phase 1: Planning & Setup
• Define success criteria and KPIs
• Identify key stakeholders and users
• Set up required infrastructure and access
• Create project timeline

[HEADING_2] Phase 2: Implementation
• Execute technical implementation
• Configure dashboards and reports
• Conduct user training
• Validate functionality

[HEADING_2] Phase 3: Go-Live & Adoption
• Launch to production
• Monitor usage and performance
• Gather user feedback
• Provide ongoing support

[HEADING_1] KEY CONTACTS

Role: Solution Architect
Name: Laurent Prat
Email: laurent.prat@databricks.com

[HEADING_1] SUCCESS CRITERIA

• Successful production deployment by target date
• User adoption within 30 days of go-live
• No critical blockers at launch

[HEADING_1] RISKS & MITIGATIONS

Risk: Timeline delays
Mitigation: Regular cadence calls, proactive blocker management

Risk: Technical blockers
Mitigation: Early engagement with support, ASQ requests as needed

[HEADING_1] NOTES

{NOTES}
```

## Variables

| Variable | Source Field | Example |
|----------|--------------|---------|
| `{UCO_NAME}` | UseCase__c.Name | UC-1 SQL DW Migration |
| `{ACCOUNT_NAME}` | Account__r.Name | Vaudoise Assurances |
| `{TARGET_DATE}` | Full_Production_Date__c | April 1, 2026 |
| `{STRATEGY}` | Implementation_Strategy__c | Self Implementation |
| `{DESCRIPTION}` | Custom based on UCO | SQL DW migration using Lakebridge |
| `{NOTES}` | Implementation_Notes__c | Project lead, special requirements |

## Bold Labels

These labels are formatted **bold**:
- Account:
- UCO Name:
- Stage:
- Target Live Date:
- Implementation Strategy:
- Role:
- Name:
- Email:
- Risk:
- Mitigation:

## Python Code to Create Formatted Onboarding Doc

```python
import json
import urllib.request
import subprocess

QUOTA_PROJECT = "gcp-sandbox-field-eng"

def get_token():
    result = subprocess.run(
        ["python3", "/Users/laurent.prat/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/google-auth/resources/google_auth.py", "token"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def create_doc(title):
    token = get_token()
    data = json.dumps({"title": title}).encode('utf-8')
    req = urllib.request.Request(
        "https://docs.googleapis.com/v1/documents",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def insert_text(doc_id, text):
    token = get_token()
    data = json.dumps({
        "requests": [{"insertText": {"location": {"index": 1}, "text": text}}]
    }).encode('utf-8')
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{doc_id}:batchUpdate",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def get_document(doc_id):
    token = get_token()
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{doc_id}",
        headers={"Authorization": f"Bearer {token}", "x-goog-user-project": QUOTA_PROJECT}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def batch_update(doc_id, requests):
    token = get_token()
    data = json.dumps({"requests": requests}).encode('utf-8')
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{doc_id}:batchUpdate",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def share_with_domain(file_id, domain="databricks.com", role="reader"):
    token = get_token()
    data = json.dumps({
        "type": "domain",
        "role": role,
        "domain": domain
    }).encode('utf-8')
    req = urllib.request.Request(
        f"https://www.googleapis.com/drive/v3/files/{file_id}/permissions",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def format_onboarding_doc(doc_id):
    """Apply formatting to onboarding doc after content insertion."""

    doc = get_document(doc_id)

    # Build content map
    content_map = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            text = ''.join(
                elem.get('textRun', {}).get('content', '')
                for elem in element['paragraph'].get('elements', [])
            ).strip()
            content_map.append({
                'start': element['startIndex'],
                'end': element['endIndex'],
                'text': text
            })

    # Apply heading styles
    requests = []
    for item in content_map:
        text = item['text']
        start = item['start']
        end = item['end']

        if text.startswith("Onboarding Plan:"):
            requests.append({"updateParagraphStyle": {"range": {"startIndex": start, "endIndex": end}, "paragraphStyle": {"namedStyleType": "TITLE"}, "fields": "namedStyleType"}})
        elif text in ["USE CASE OVERVIEW", "OBJECTIVE", "ONBOARDING MILESTONES", "KEY CONTACTS", "SUCCESS CRITERIA", "RISKS & MITIGATIONS", "NOTES"]:
            requests.append({"updateParagraphStyle": {"range": {"startIndex": start, "endIndex": end}, "paragraphStyle": {"namedStyleType": "HEADING_1"}, "fields": "namedStyleType"}})
        elif text.startswith("Phase 1:") or text.startswith("Phase 2:") or text.startswith("Phase 3:"):
            requests.append({"updateParagraphStyle": {"range": {"startIndex": start, "endIndex": end}, "paragraphStyle": {"namedStyleType": "HEADING_2"}, "fields": "namedStyleType"}})

    if requests:
        batch_update(doc_id, requests)

    # Find and apply bullet formatting
    doc = get_document(doc_id)
    content_map = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            text = ''.join(elem.get('textRun', {}).get('content', '') for elem in element['paragraph'].get('elements', [])).strip()
            content_map.append({'start': element['startIndex'], 'end': element['endIndex'], 'text': text})

    bullet_ranges = []
    current_start = None
    current_end = None
    for item in content_map:
        if item['text'].startswith("- "):
            if current_start is None:
                current_start = item['start']
            current_end = item['end']
        else:
            if current_start is not None:
                bullet_ranges.append((current_start, current_end))
                current_start = None
    if current_start is not None:
        bullet_ranges.append((current_start, current_end))

    if bullet_ranges:
        bullet_requests = [{"createParagraphBullets": {"range": {"startIndex": s, "endIndex": e}, "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"}} for s, e in bullet_ranges]
        batch_update(doc_id, bullet_requests)

    # Clean up "- " prefixes
    cleanup = [
        {"replaceAllText": {"containsText": {"text": "- Define", "matchCase": True}, "replaceText": "Define"}},
        {"replaceAllText": {"containsText": {"text": "- Identify", "matchCase": True}, "replaceText": "Identify"}},
        {"replaceAllText": {"containsText": {"text": "- Set up", "matchCase": True}, "replaceText": "Set up"}},
        {"replaceAllText": {"containsText": {"text": "- Create", "matchCase": True}, "replaceText": "Create"}},
        {"replaceAllText": {"containsText": {"text": "- Execute", "matchCase": True}, "replaceText": "Execute"}},
        {"replaceAllText": {"containsText": {"text": "- Configure", "matchCase": True}, "replaceText": "Configure"}},
        {"replaceAllText": {"containsText": {"text": "- Conduct", "matchCase": True}, "replaceText": "Conduct"}},
        {"replaceAllText": {"containsText": {"text": "- Validate", "matchCase": True}, "replaceText": "Validate"}},
        {"replaceAllText": {"containsText": {"text": "- Launch", "matchCase": True}, "replaceText": "Launch"}},
        {"replaceAllText": {"containsText": {"text": "- Monitor", "matchCase": True}, "replaceText": "Monitor"}},
        {"replaceAllText": {"containsText": {"text": "- Gather", "matchCase": True}, "replaceText": "Gather"}},
        {"replaceAllText": {"containsText": {"text": "- Provide", "matchCase": True}, "replaceText": "Provide"}},
        {"replaceAllText": {"containsText": {"text": "- Successful", "matchCase": True}, "replaceText": "Successful"}},
        {"replaceAllText": {"containsText": {"text": "- User adoption", "matchCase": True}, "replaceText": "User adoption"}},
        {"replaceAllText": {"containsText": {"text": "- No critical", "matchCase": True}, "replaceText": "No critical"}},
        {"replaceAllText": {"containsText": {"text": "- Risk:", "matchCase": True}, "replaceText": "Risk:"}},
    ]
    batch_update(doc_id, cleanup)

    # Bold key labels
    doc = get_document(doc_id)
    bold_patterns = ["Account:", "UCO Name:", "Stage:", "Target Live Date:", "Implementation Strategy:", "Role:", "Name:", "Email:", "Risk:", "Mitigation:"]
    bold_requests = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for text_elem in element['paragraph'].get('elements', []):
                if 'textRun' in text_elem:
                    content = text_elem['textRun'].get('content', '')
                    start = text_elem['startIndex']
                    for pattern in bold_patterns:
                        if pattern in content:
                            pos = content.find(pattern)
                            bold_requests.append({"updateTextStyle": {"range": {"startIndex": start + pos, "endIndex": start + pos + len(pattern)}, "textStyle": {"bold": True}, "fields": "bold"}})

    if bold_requests:
        for i in range(0, len(bold_requests), 50):
            batch_update(doc_id, bold_requests[i:i+50])

# Example usage:
# content = generate_content(uco_data)  # Generate plain text content
# doc = create_doc(f"Onboarding Plan: {uco_name}")
# doc_id = doc['documentId']
# insert_text(doc_id, content)
# format_onboarding_doc(doc_id)
# share_with_domain(doc_id)
```

## Plain Text Content Template

Use this to generate the initial content before formatting:

```python
def generate_onboarding_content(uco):
    return f"""Onboarding Plan: {uco['name']}

USE CASE OVERVIEW

Account: {uco['account']}
UCO Name: {uco['name']}
Stage: U5 - Onboarding
Target Live Date: {uco['target_date']}
Implementation Strategy: {uco['strategy']}

OBJECTIVE

{uco['description']}

ONBOARDING MILESTONES

Phase 1: Planning & Setup
- Define success criteria and KPIs
- Identify key stakeholders and users
- Set up required infrastructure and access
- Create project timeline

Phase 2: Implementation
- Execute technical implementation
- Configure dashboards and reports
- Conduct user training
- Validate functionality

Phase 3: Go-Live & Adoption
- Launch to production
- Monitor usage and performance
- Gather user feedback
- Provide ongoing support

KEY CONTACTS

Role: Solution Architect
Name: Laurent Prat
Email: laurent.prat@databricks.com

SUCCESS CRITERIA

- Successful production deployment by target date
- User adoption within 30 days of go-live
- No critical blockers at launch

RISKS & MITIGATIONS

- Risk: Timeline delays
Mitigation: Regular cadence calls, proactive blocker management

- Risk: Technical blockers
Mitigation: Early engagement with support, ASQ requests as needed

NOTES

{uco['notes']}
"""
```

## Attaching to Salesforce UCO

### Clickable Link (via API) - RECOMMENDED
Update `Artifact_Link__c` field - displays as **"Onboarding Doc (Link)"** in MEDDPICC > Path to Production section:
```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Artifact_Link__c='https://docs.google.com/document/d/<DOC_ID>/edit'"
```

### Associate Documents Section (Manual)
The "Associate Documents" modal requires **manual entry through the UI**:
1. Open the UCO in Salesforce
2. Click **"Associate Documents"** button
3. Paste the Google Doc URL in the **"Onboarding Doc"** row
4. Click **Save**

**Note**: Creating `GoogleDoc` records via API does not populate the "Associate Documents" modal.

## Checklist for New U5 Onboarding Docs

1. [ ] Query U5 UCO details from Salesforce
2. [ ] Create Google Doc with plain text content
3. [ ] Apply formatting (title, headings, bullets, bold)
4. [ ] Share doc with databricks.com domain as VIEWER
5. [ ] Verify doc ownership is laurent.prat@databricks.com
6. [ ] **API**: Set `Artifact_Link__c` field (clickable link in MEDDPICC section)
7. [ ] **Optional**: Append link to `Use_Case_Description__c` for copy-paste access
8. [ ] **MANUAL**: Open UCO → Associate Documents → paste URL in "Onboarding Doc" → Save

---

## Quick Reference: Field Names

| What You Want | API Field Name | UI Location |
|---------------|----------------|-------------|
| Clickable onboarding link | `Artifact_Link__c` | MEDDPICC > Path to Production |
| Description text | `Use_Case_Description__c` | Overview section |
| Eval doc link | `POC_Doc__c` | MEDDPICC > Decision Criteria |

**Common Mistake**: `Description__c` is NOT the Overview "Description" field - use `Use_Case_Description__c` instead.

---
name: jira-actions
description: Read, search, clone, comment, and create JIRA ES tickets for engineering support
---

# JIRA Actions Skill

Read, search, clone, comment, and create Engineering Support (ES) tickets using the Atlassian CLI (acli).

## Prerequisites

### 1. Check acli Installation
```bash
which acli
```
If not found, run the `configure-vibe` skill to install: `brew install acli`

### 2. Check Authentication
```bash
acli jira auth status
```

If not authenticated, follow the authentication steps in `configure-vibe`:
1. Create API token at: https://id.atlassian.com/manage-profile/security
2. Set environment variable:
   ```bash
   echo 'export ATLASSIAN_API_KEY="<YOUR_TOKEN>"' >> ~/.zshrc
   source ~/.zshrc
   ```
3. Login:
   ```bash
   echo $ATLASSIAN_API_KEY | acli jira auth login \
     --site=https://databricks.atlassian.net/ \
     --email=$USER@databricks.com \
     --token
   ```

## Important Access Restrictions

**CRITICAL**: Since December 2024, most Field Engineering members (SAs, DSAs, SSAs, RSAs, STS below L7) cannot create ES tickets directly in JIRA. They must use:
- **go/FEfileaticket** - The JIRA Portal for filing tickets (preferred)
- **go/fe-break-glass** - Temporary 1-hour access via Opal for emergencies
- **Clone existing tickets** - Find similar tickets and clone them (works if you can view the ticket)

Only users in the **FE.Exception.ES.Access** group can create tickets directly.

## Operations

### Search ES Tickets

Find tickets using JQL (JIRA Query Language):

```bash
# Search by keyword
acli jira workitem search --jql "project = ES AND summary ~ 'keyword'" --limit 20

# Search by customer name
acli jira workitem search --jql "project = ES AND summary ~ 'CustomerName'" --limit 10

# Search by component
acli jira workitem search --jql "project = ES AND component = 'Storage.Delta'" --limit 10

# Search by issue type
acli jira workitem search --jql "project = ES AND issuetype = 'Incident'" --limit 10

# Search recent tickets
acli jira workitem search --jql "project = ES ORDER BY created DESC" --limit 20

# Get JSON output for parsing
acli jira workitem search --jql "project = ES AND summary ~ 'keyword'" --limit 10 --json
```

### View ES Ticket Details

```bash
# View basic fields
acli jira workitem view ES-123456

# View all fields (full detail)
acli jira workitem view ES-123456 --fields '*all' --json

# Open in browser
acli jira workitem view ES-123456 --web
```

### Add Comments (Non-Destructive)

```bash
# Add a comment
acli jira workitem comment --key ES-123456 --body "Your comment here"

# Add comment from file
acli jira workitem comment --key ES-123456 --body-file comment.txt
```

### Clone ES Tickets (Recommended for Creating New Tickets)

This is the preferred method for FE who don't have direct ES create access:

```bash
# 1. Find a similar ticket to use as template
acli jira workitem search --jql "project = ES AND summary ~ 'quota increase'" --limit 5

# 2. Clone the ticket
acli jira workitem clone --key ES-TEMPLATE_ID --to-project ES -y

# 3. Edit the cloned ticket with new details
acli jira workitem edit --key ES-NEW_ID \
  --summary "New Summary Here" \
  --description "New description here"
```

### Edit Existing Tickets

```bash
# Edit summary
acli jira workitem edit --key ES-123456 --summary "Updated Summary"

# Edit with JSON file for complex changes
acli jira workitem edit --from-json workitem.json
```

### Create ES Tickets (Restricted Access)

**Only use if you have FE.Exception.ES.Access permission or break-glass access.**

```bash
# Create an Incident
acli jira workitem create \
  --project ES \
  --type "Incident" \
  --summary "[CustomerName] Brief description of the issue" \
  --description "Detailed description"

# Create a Customization/Service Request
acli jira workitem create \
  --project ES \
  --type "Customization/Service Request" \
  --summary "[CustomerName] Request for quota increase" \
  --description "Details of the request"
```

**If create fails with permission error:**
1. Use go/FEfileaticket portal instead
2. Or request break-glass access via go/fe-break-glass (temporary 1-hour access)
3. Or clone an existing similar ticket and modify it

## Issue Type Reference

See `resources/ES_TICKET_TYPES.md` for detailed information on:
- Incident
- Advanced Support
- Customization/Service Request
- Private Preview Bugs
- Xteam-Ask

## Severity Level Reference

See `resources/ES_SEVERITY_LEVELS.md` for definitions of:
- SEV0 (Critical) - Total outages, data integrity, >$10k impact
- SEV1 (High) - Partial outages, production impact
- SEV2 (Standard Non-Critical) - Customer impacting but not critical
- SEV3 (Low) - Trivial, minimal impact

## Key Fields Reference

See `resources/ES_KEY_FIELDS.md` for common custom fields:
- Support Severity Level
- Workspace ID
- Cloud (AWS/Azure/GCP)
- Customer Name
- Component/Service Area

## Best Practices

1. **Always search first** - Look for similar existing tickets before creating new ones
2. **Clone when possible** - Cloning preserves proper field structure
3. **Use descriptive summaries** - Include customer name: `[CustomerName] Brief issue description`
4. **Set correct severity** - Follow the severity level guidelines
5. **Assign to Unassigned** - Let the owning team triage unless you know the assignee
6. **Link related tickets** - Reference Salesforce cases, other ES tickets
7. **Include workspace IDs** - Always include affected workspace IDs

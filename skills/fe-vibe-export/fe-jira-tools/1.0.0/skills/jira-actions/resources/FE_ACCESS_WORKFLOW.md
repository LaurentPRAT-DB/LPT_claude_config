# Field Engineering ES Ticket Access Workflow

This document describes the workflow for Field Engineering members to work with ES tickets given the access restrictions implemented in December 2024.

## Access Levels

### Standard FE Access (Most FE Members)
- **Can:** Search, view, comment, clone tickets
- **Cannot:** Create new tickets directly in ES project
- **Must use:** go/FEfileaticket portal for new tickets

### FE Exception Access (FE.Exception.ES.Access Group)
- **Can:** All operations including direct ticket creation
- **Group:** FE.Exception.ES.Access in Opal
- **Who:** Typically L7+ or those with specific approval

### Break Glass Access (Temporary)
- **Duration:** 1 hour
- **Use case:** Emergencies, engineering-requested tickets
- **How:** Request via go/fe-break-glass (Opal)
- **Approvers:** Listed in Opal

## Workflow Decision Tree

```
Need to work with ES ticket?
│
├─ View/Search existing ticket?
│  └─ YES: Use acli jira workitem search/view (no restrictions)
│
├─ Add comment to existing ticket?
│  └─ YES: Use acli jira workitem comment (no restrictions)
│
├─ Edit existing ticket?
│  └─ YES: Use acli jira workitem edit (limited, non-destructive)
│
├─ Create NEW ticket?
│  │
│  ├─ Have FE.Exception.ES.Access?
│  │  └─ YES: Use acli jira workitem create
│  │
│  ├─ Is this a SEV0 emergency?
│  │  └─ YES: Email help@databricks.com for immediate Support engagement
│  │
│  ├─ Customer has support contract?
│  │  └─ YES: Use go/FEfileaticket portal (creates SFDC case + ES ticket)
│  │
│  ├─ Can reproduce on internal workspace?
│  │  └─ YES: File via portal using internal workspace ID
│  │
│  ├─ Engineering team asked you to file ES?
│  │  └─ YES: Use go/fe-break-glass for temporary access
│  │
│  └─ Similar ticket exists to clone?
│     └─ YES: Clone the ticket and modify it
```

## go/FEfileaticket Portal

### When to Use
- Customer with support contract (Incident, Advanced Support)
- Azure customers with Azure support ticket
- Internally discovered bugs
- Private Preview bugs
- Service requests (Genie Access, NOC monitoring, Audit Log, Quota Increase)

### What It Creates
- For customers with support: Creates Salesforce case AND ES ticket
- For internal workspaces: Creates ES ticket directly
- For customers without support: Closed as "No Support"

### Available Request Types
| Portal Form | Maps To |
|------------|---------|
| Incident (FE) | ES Incident |
| Advanced Support (FE) | ES Advanced Support |
| Customization/Service Request (FE) | ES Customization/Service Request |
| Beta Product / Private Preview Bugs (FE) | ES Private Preview Bugs |
| Audit Logs (FE) | ES Customization/Service Request |
| Genie Access (FE) | ES Customization/Service Request |
| NOC Monitoring (FE) | ES Customization/Service Request |
| Quota Increase (FE) | ES Customization/Service Request |

### Limitations
- SEV0 cannot be filed (downgraded to SEV1)
- No inline image paste in description fields
- Must have valid workspace ID with support contract

## go/fe-break-glass (Emergency Access)

### When to Use
1. Portal is unavailable
2. Engineering team explicitly asked you to file ES ticket
3. Cannot reproduce bug on internal workspace
4. Customer unique issue with no support contract

### How to Request
1. Go to Opal: go/fe-break-glass
2. Request "ES Ticket Access" application
3. Provide justification
4. Wait for approval (auto-approved or quick approval)
5. Access granted for 1 hour

### After Getting Access
- Navigate to JIRA ES project directly
- Create ticket with appropriate type and severity
- Follow ES ticket best practices (see go/esguide)

## Cloning Workflow

When you can't create directly but can find a similar ticket:

```bash
# 1. Search for similar tickets
acli jira workitem search --jql "project = ES AND summary ~ 'quota increase FMAPI'" --limit 10

# 2. Find a good template (similar issue type, same team/component)
acli jira workitem view ES-XXXXXX --json

# 3. Clone the ticket
acli jira workitem clone --key ES-XXXXXX --to-project ES -y

# 4. Note the new ticket key from output

# 5. Update the cloned ticket
acli jira workitem edit --key ES-NEW_KEY \
  --summary "[NewCustomer] Your specific issue summary" \
  --description "Your specific description"
```

### Good Clone Templates
- Same issue type
- Same component/team
- Similar request (e.g., same type of quota increase)
- Resolved tickets often have better structure

## Do NOT

- Clone tickets just to bypass support triage (abuse of system)
- File SEV0 through the portal (use help@databricks.com)
- Create tickets for customers without support contracts (unless internal repro)
- Skip the portal when customer has support contract

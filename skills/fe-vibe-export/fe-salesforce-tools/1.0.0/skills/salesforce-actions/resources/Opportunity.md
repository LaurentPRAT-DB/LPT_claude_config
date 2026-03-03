# Opportunity Object

## Overview
The Opportunity object represents potential sales deals in Salesforce. It tracks sales stages, amounts, and close dates.

## Required Fields for Creation
- `Name` (string) - Opportunity name
- `StageName` (picklist) - Current stage of the opportunity
- `CloseDate` (date) - Expected close date (format: YYYY-MM-DD)

## Key Fields

### Standard Fields
- `AccountId` (reference) - Related Account ID (18-character Salesforce ID)
- `Amount` (currency) - Opportunity amount in dollars
- `Probability` (percent) - Win probability (0-100)
- `Type` (picklist) - Opportunity type
- `LeadSource` (picklist) - Origin of the opportunity
- `Description` (textarea) - Detailed description
- `OwnerId` (reference) - User ID of the owner
- `IsClosed` (boolean) - Whether the opportunity is closed
- `IsWon` (boolean) - Whether the opportunity was won

### Picklist Values
**StageName**: Prospecting, Qualification, Needs Analysis, Value Proposition, Id. Decision Makers, Perception Analysis, Proposal/Price Quote, Negotiation/Review, Closed Won, Closed Lost

**Type**: Existing Customer - Upgrade, Existing Customer - Replacement, Existing Customer - Downgrade, New Customer

**LeadSource**: Web, Phone Inquiry, Partner Referral, Purchased List, Other

## CLI Commands

### Create an Opportunity
```bash
sf data create record --sobject Opportunity \
  --values "Name='Q1 2025 Enterprise Deal' StageName='Prospecting' CloseDate='2025-03-31' Amount=50000 AccountId='001xx000003DGb2AAG'"
```

### Query Opportunities
```bash
# Get all open opportunities
sf data query --query "SELECT Id, Name, StageName, Amount, CloseDate FROM Opportunity WHERE IsClosed = false"

# Get opportunities by stage
sf data query --query "SELECT Id, Name, Amount, CloseDate FROM Opportunity WHERE StageName = 'Prospecting'"

# Get opportunities closing this quarter
sf data query --query "SELECT Id, Name, Amount, CloseDate FROM Opportunity WHERE CloseDate = THIS_QUARTER"

# Get specific opportunity by ID
sf data query --query "SELECT Id, Name, StageName, Amount, CloseDate, AccountId FROM Opportunity WHERE Id = '006xx000001234AAA'"
```

### Update an Opportunity
```bash
# Update stage and amount
sf data update record --sobject Opportunity \
  --record-id 006xx000001234AAA \
  --values "StageName='Negotiation/Review' Amount=75000"

# Update close date
sf data update record --sobject Opportunity \
  --record-id 006xx000001234AAA \
  --values "CloseDate='2025-04-15'"
```

## Notes
- Use 18-character Salesforce IDs for reference fields (AccountId, OwnerId)
- Currency amounts are entered as numbers without currency symbols
- Date format is YYYY-MM-DD
- Boolean fields accept `true` or `false`
- Picklist values are case-sensitive and must match exactly

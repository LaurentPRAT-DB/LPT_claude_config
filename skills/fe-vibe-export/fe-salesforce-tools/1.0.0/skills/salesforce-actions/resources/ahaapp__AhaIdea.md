# ahaapp__AhaIdea__c

Aha! Ideas synced to Salesforce.

## Required Fields

- **OwnerId** (reference) - Owner ID
  - Type: User or Group ID
  - Required: Yes

## Optional Fields

- **Name** (string) - Idea Name
  - Max length: 80 characters

- **CurrencyIsoCode** (picklist) - Currency ISO Code
  - Default: USD
  - Values: `USD`

- **ahaapp__ReferenceNum__c** (string) - Aha! Reference
  - Aha! idea reference number

- **ahaapp__Status__c** (string) - Status
  - Current status of the idea

## Fields That Do NOT Exist

**IMPORTANT**: The following field names do NOT exist on the ahaapp__AhaIdea__c object:
- `ahaapp__Idea_URL__c` - Does not exist
- `ahaapp__Record_URL__c` - Does not exist
- `ahaapp__Link__c` - Does not exist

To get the AHA Idea URL, use the `ahaapp__ReferenceNum__c` field and construct the URL as:
`https://databricks.aha.io/ideas/{ahaapp__ReferenceNum__c}` (e.g., `https://databricks.aha.io/ideas/DB-I-15903`)

## Create (POST)

```bash
# Create a new Aha! Idea
sf data create record -o databricks -s ahaapp__AhaIdea__c -v "Name='New Feature Request' OwnerId='0056100000AExampleAAD' ahaapp__Status__c='Under Review'"
```

## Read/Query (GET)

```bash
# Query all Aha! Ideas
sf data query -o databricks -q "SELECT Id, Name, ahaapp__ReferenceNum__c, ahaapp__Status__c, OwnerId FROM ahaapp__AhaIdea__c"

# Query by specific criteria
sf data query -o databricks -q "SELECT Id, Name, ahaapp__Status__c FROM ahaapp__AhaIdea__c WHERE ahaapp__Status__c = 'Under Review'"

# Get a specific record
sf data get record -o databricks -s ahaapp__AhaIdea__c -i a0A6100000ExampleAAA
```

## Update (PATCH)

```bash
# Update an existing Aha! Idea
sf data update record -o databricks -s ahaapp__AhaIdea__c -i a0A6100000ExampleAAA -v "ahaapp__Status__c='Approved'"

# Update multiple fields
sf data update record -o databricks -s ahaapp__AhaIdea__c -i a0A6100000ExampleAAA -v "Name='Updated Feature' ahaapp__Status__c='In Progress'"
```

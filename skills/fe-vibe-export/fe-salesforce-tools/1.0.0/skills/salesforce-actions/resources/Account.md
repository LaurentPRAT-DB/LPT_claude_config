# Account Object

Standard Salesforce object representing business accounts/organizations.

## Required Fields for Creation

- **Name** (string) - Account name

## Common Fields

### Basic Information
- **Name** (string) - Account name (required)
- **Type** (picklist) - Account type
  - Values: Prospect, Customer - Direct, Customer - Channel, Channel Partner / Reseller, Installation Partner, Technology Partner, Other
- **Industry** (picklist) - Account's industry
- **Website** (string) - Account website URL
- **Description** (textarea) - Account description

### Contact Information
- **Phone** (string) - Main phone number
- **BillingStreet** (textarea) - Billing street address
- **BillingCity** (string) - Billing city
- **BillingState** (string) - Billing state/province
- **BillingPostalCode** (string) - Billing postal code
- **BillingCountry** (string) - Billing country
- **ShippingStreet** (textarea) - Shipping street address
- **ShippingCity** (string) - Shipping city
- **ShippingState** (string) - Shipping state/province
- **ShippingPostalCode** (string) - Shipping postal code
- **ShippingCountry** (string) - Shipping country

### Relationships
- **ParentId** (reference) - Parent account ID for account hierarchies
- **OwnerId** (reference) - User ID of account owner

### System Fields
- **Id** (id) - Unique identifier (read-only)
- **CreatedDate** (datetime) - Creation timestamp (read-only)
- **LastModifiedDate** (datetime) - Last modification timestamp (read-only)

## Example Commands

### Create Account
```bash
sf data create record --sobject Account --values "Name='Acme Corporation' Type='Prospect' Industry='Technology' Website='https://acme.com'"
```

### Query Accounts
```bash
# Get all accounts
sf data query --query "SELECT Id, Name, Type, Industry, Website FROM Account LIMIT 10"

# Query by name
sf data query --query "SELECT Id, Name, Type, Phone, Website FROM Account WHERE Name LIKE '%Acme%'"

# Query with relationships
sf data query --query "SELECT Id, Name, Owner.Name, Parent.Name FROM Account WHERE Type = 'Customer - Direct'"
```

### Get Single Account
```bash
sf data get record --sobject Account --record-id 001XXXXXXXXXXXXXXX
```

### Update Account
```bash
# Update single field
sf data update record --sobject Account --record-id 001XXXXXXXXXXXXXXX --values "Phone='555-1234'"

# Update multiple fields
sf data update record --sobject Account --record-id 001XXXXXXXXXXXXXXX --values "Phone='555-1234' Website='https://newacme.com' Type='Customer - Direct'"
```

## Notes

- Account Name is the only required field for creation
- Type field uses restricted picklist values
- Use SOQL queries to search and filter accounts
- Record IDs always start with "001" for Account objects

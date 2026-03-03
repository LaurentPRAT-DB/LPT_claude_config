# Salesforce Account Lookup Guide

This guide provides instructions for using the Salesforce CLI to lookup accounts in Salesforce.

## Prerequisites

- Salesforce CLI installed (`sf` command)
- Authenticated to a Salesforce org (use `sf org login web` or `sf org login jwt`)

## Verify Current User

To check which user you're currently logged in as:

```bash
sf org display
```

Or to see the current user's details:

```bash
sf org display user
```

## Looking Up a Specific Account

### Query Account by Name

```bash
sf data query --query "SELECT Id, Name, Type, Industry, Website, Phone FROM Account WHERE Name LIKE '%SearchTerm%'"
```

### Query Account by ID

```bash
sf data query --query "SELECT Id, Name, Type, Industry, Website, Phone, OwnerId, Owner.Name FROM Account WHERE Id = '001XXXXXXXXXX'"
```

### Query Account by Domain/Website

```bash
sf data query --query "SELECT Id, Name, Website, Phone FROM Account WHERE Website LIKE '%example.com%'"
```

## Looking Up Accounts Associated with Current User

### Get Current User ID

First, get your user ID:

```bash
sf data query --query "SELECT Id, Name, Email FROM User WHERE Username = 'your.email@domain.com'"
```

Or get the current authenticated user:

```bash
sf org display user --json | grep '"id"'
```

### Query Accounts Owned by Current User

Using the User ID from above:

```bash
sf data query --query "SELECT Id, Name, Type, Industry, CreatedDate FROM Account WHERE OwnerId = 'YOUR_USER_ID'"
```

### Query Accounts with Recent Activity by Current User

```bash
sf data query --query "SELECT Id, Name, LastModifiedById, LastModifiedBy.Name, LastModifiedDate FROM Account WHERE LastModifiedById = 'YOUR_USER_ID' ORDER BY LastModifiedDate DESC LIMIT 10"
```

### Query All Accounts You Have Access To (Limited)

```bash
sf data query --query "SELECT Id, Name, Type, Owner.Name FROM Account ORDER BY LastModifiedDate DESC LIMIT 20"
```

## Useful Query Options

### Output in JSON Format

Add `--json` flag for JSON output:

```bash
sf data query --query "SELECT Id, Name FROM Account LIMIT 5" --json
```

### Output to CSV File

```bash
sf data query --query "SELECT Id, Name, Type, Industry FROM Account LIMIT 100" --result-format csv > accounts.csv
```

### Using a Specific Org

If you have multiple orgs authenticated:

```bash
sf data query --query "SELECT Id, Name FROM Account" --target-org my-org-alias
```

## Common Account Fields

Here are commonly used Account fields for queries:

- `Id` - Unique account identifier
- `Name` - Account name
- `Type` - Account type (e.g., Customer, Prospect)
- `Industry` - Industry classification
- `Website` - Company website
- `Phone` - Primary phone number
- `BillingAddress` - Billing address
- `ShippingAddress` - Shipping address
- `OwnerId` - User ID of account owner
- `Owner.Name` - Name of account owner (relationship query)
- `CreatedDate` - When account was created
- `LastModifiedDate` - When account was last modified
- `LastModifiedById` - User who last modified the account

## Advanced Examples

### Query with Multiple Conditions

```bash
sf data query --query "SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE Industry = 'Technology' AND AnnualRevenue > 1000000 ORDER BY AnnualRevenue DESC"
```

### Query Accounts with Related Contacts

```bash
sf data query --query "SELECT Id, Name, (SELECT Id, Name, Email FROM Contacts) FROM Account WHERE Name LIKE '%Acme%'"
```

### Count Accounts by Owner

```bash
sf data query --query "SELECT OwnerId, Owner.Name, COUNT(Id) AccountCount FROM Account GROUP BY OwnerId, Owner.Name ORDER BY COUNT(Id) DESC"
```

## Tips

1. **Use LIMIT**: Always use `LIMIT` when exploring data to avoid timeout issues
2. **Escape Special Characters**: Wrap strings with special characters in single quotes
3. **Check Permissions**: You can only query accounts you have access to based on your profile and sharing rules
4. **API Limits**: Be mindful of API call limits in your org
5. **Field-Level Security**: Some fields may not be visible if field-level security restricts access

## Troubleshooting

If you encounter errors:

- **"Entity is not api accessible"**: Check that the API name is correct
- **"No such column"**: Verify the field name exists and you have access
- **Authentication errors**: Re-authenticate with `sf org login web`
- **Timeout errors**: Reduce the query scope or add more specific WHERE clauses

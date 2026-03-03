# User Object

## Overview
The User object represents Salesforce users who can log into the organization. Users have permissions and access rights based on their profile, role, and permission sets.

## Required Fields for Creation

The User object has many required fields. Key required fields include:

- **Username** (string) - Must be unique across all Salesforce orgs and in email format
- **LastName** (string) - User's last name
- **Email** (email) - User's email address
- **Alias** (string) - Short name (max 8 chars) to identify the user
- **CommunityNickname** (string) - Nickname used in communities
- **TimeZoneSidKey** (picklist) - User's time zone (e.g., "America/Los_Angeles")
- **LocaleSidKey** (picklist) - User's locale (e.g., "en_US")
- **EmailEncodingKey** (picklist) - Encoding for emails (e.g., "UTF-8")
- **LanguageLocaleKey** (picklist) - User's language (e.g., "en_US")
- **IsActive** (boolean) - Whether user is active

Note: User creation requires system administrator permissions and is typically done through the UI or specialized provisioning tools. Many preference fields have required boolean defaults.

## Common Optional Fields

- **FirstName** (string) - User's first name
- **MiddleName** (string) - User's middle name
- **Phone** (phone) - Phone number
- **MobilePhone** (phone) - Mobile phone number
- **Title** (string) - Job title
- **Department** (string) - Department name
- **CompanyName** (string) - Company name
- **UserRoleId** (reference) - ID of the user's role
- **ManagerId** (reference) - ID of the user's manager
- **City** (string), **State** (string), **Country** (string) - Address fields
- **StateCode** (picklist), **CountryCode** (picklist) - ISO codes for state/country

## Picklist Fields

- **StateCode** - 610 values (ISO state/province codes)
- **CountryCode** - 251 values (ISO country codes)
- **TimeZoneSidKey** - 424 values (e.g., "America/New_York", "Europe/London")
- **LocaleSidKey** - 279 values (e.g., "en_US", "de_DE")
- **LanguageLocaleKey** - 18 values (e.g., "en_US", "es", "fr")
- **EmailEncodingKey** - 10 values (e.g., "UTF-8", "ISO-8859-1")

## CLI Commands

### Query Users (Read)

```bash
# Query all active users
sf data query --query "SELECT Id, Name, Username, Email, IsActive FROM User WHERE IsActive = true"

# Query specific user by username
sf data query --query "SELECT Id, Name, Username, Email, Phone, Title FROM User WHERE Username = 'user@example.com'"

# Query users by name
sf data query --query "SELECT Id, Name, Username, Email FROM User WHERE Name LIKE '%Smith%'"

# Get user details by ID
sf data query --query "SELECT Id, Name, Username, Email, Title, Department, Phone, MobilePhone, IsActive FROM User WHERE Id = '0053f000000WE1D'"
```

### Create User (Post)

Note: User creation is complex and requires administrator permissions. This is typically done through Setup UI.

```bash
# Create a new user (simplified example - many required fields not shown)
sf data create record --sobject User --values \
  "Username='newuser@example.com' \
   LastName='Doe' \
   FirstName='John' \
   Email='john.doe@example.com' \
   Alias='jdoe' \
   CommunityNickname='jdoe123' \
   TimeZoneSidKey='America/Los_Angeles' \
   LocaleSidKey='en_US' \
   EmailEncodingKey='UTF-8' \
   LanguageLocaleKey='en_US' \
   IsActive=true"
```

### Update User (Patch)

```bash
# Update user phone and title
sf data update record --sobject User --record-id 0053f000000WE1D \
  --values "Phone='555-0100' Title='Senior Developer'"

# Deactivate a user
sf data update record --sobject User --record-id 0053f000000WE1D \
  --values "IsActive=false"

# Update user's email
sf data update record --sobject User --record-id 0053f000000WE1D \
  --values "Email='newemail@example.com'"

# Update multiple fields
sf data update record --sobject User --record-id 0053f000000WE1D \
  --values "FirstName='Jane' LastName='Smith' Phone='555-0200' MobilePhone='555-0201'"
```

## Notes

- Users cannot be deleted in Salesforce, only deactivated (set IsActive=false)
- Username must be unique across all Salesforce organizations
- Most organizations have validation rules and required custom fields
- Creating users typically requires specific profiles and permission sets
- Many boolean preference fields default to false but are required on creation

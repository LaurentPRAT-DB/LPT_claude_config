# Emburse Authentication

ChromeRiver uses session-based authentication via Okta SAML SSO. The session cookie (`JSESSIONID`) is httpOnly and cannot be extracted via JavaScript.

## Authentication Flow

1. **User navigates to Okta SSO URL in Chrome:**
   ```
   https://databricks.okta.com/app/databricks_chromeriver_1/exk1n5wwxjvwa24Km1d8/sso/saml?fromHome=true
   ```

2. **User completes authentication** (including any 2FA)

3. **Extract session credentials using Chrome DevTools MCP:**
   - The `JSESSIONID` cookie is captured from network requests
   - Required headers are extracted from API calls

## Required Headers

All API requests must include these headers:

```
customer-id: 3035
person-id: <user-person-id>
logged-in-user-id: <user-person-id>
delegate-person-id: <user-person-id>
chain-id: <unique-uuid-per-request>
x-requested-with: XMLHttpRequest
content-type: application/json
accept: application/json
Cookie: JSESSIONID=<session-cookie>
```

**Note:** `chain-id` should be a unique identifier for request tracing (format: `xxxx-xxxx-xxxx-xxxx-xxxx`).

## Base URL

```
https://app.ca1.chromeriver.com/apollo/
```

## Session Management

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Keep session alive | POST | `/apollo/system/cr-internal/keepAlive` |
| Check session | GET | `/apollo/system/cr-internal/isAlive` |

## Executing API Requests

### Option 1: Chrome DevTools MCP (Recommended)

Use Chrome DevTools MCP to execute requests in the browser context where the session is already authenticated.

```javascript
// Using chrome-devtools/evaluate_script MCP tool
fetch('/apollo/v2/expenseTransactions?status=ACTIVE', {
  headers: {
    'customer-id': '3035',
    'person-id': '<personId>',
    'logged-in-user-id': '<personId>',
    'delegate-person-id': '<personId>',
    'chain-id': crypto.randomUUID(),
    'x-requested-with': 'XMLHttpRequest',
    'accept': 'application/json'
  }
}).then(r => r.json()).then(console.log)
```

**Advantages:**
- Session cookies are automatically included
- No need to extract/manage JSESSIONID
- Works within existing browser security context

### Option 2: Extract Session and Use curl

Extract the session cookie from browser network requests and use curl for subsequent API calls.

```bash
curl -X GET 'https://app.ca1.chromeriver.com/apollo/v2/expenseTransactions?status=ACTIVE' \
  -H 'customer-id: 3035' \
  -H 'person-id: <personId>' \
  -H 'logged-in-user-id: <personId>' \
  -H 'delegate-person-id: <personId>' \
  -H 'chain-id: <uuid>' \
  -H 'x-requested-with: XMLHttpRequest' \
  -H 'content-type: application/json' \
  -H 'accept: application/json' \
  -H 'Cookie: JSESSIONID=<session-cookie>'
```

## Generating chain-id

The `chain-id` header should be a unique UUID for request tracing:

```bash
# Bash
uuidgen | tr '[:upper:]' '[:lower:]'

# Or in JavaScript
crypto.randomUUID()
```

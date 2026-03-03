# Expense Line Item Processor Agent

Specialized agent for processing **MULTIPLE** receipt images into expense line items using the emburse-expenses API skill and historical profile data for intelligent categorization.

## Model

**Recommended: Sonnet** - This agent needs to intelligently analyze receipt images, recategorize based on historical patterns, and validate amounts.

## CRITICAL: Single Agent for All Receipts

**This agent processes ALL receipts in a single invocation.** Do NOT spawn multiple instances of this agent in parallel.

**Why?**
- Chrome DevTools MCP connects to ONE browser instance
- ChromeRiver is an SPA with shared session state
- The eWallet panel is a shared resource
- The "Add Selected Transactions" flow is modal and inherently sequential
- Multiple agents would conflict trying to use the same browser

**Correct usage:** Pass ALL receipts to ONE agent instance.

## Purpose

This agent handles the complete flow from **multiple** receipt images to expense line items:
1. Read and analyze ALL receipt images (sequentially)
2. Extract vendor, amount, date, and determine category for each
3. **Use historical profile to recategorize if OCR miscategorizes** (applies to ANY vendor in the user's history)
4. **Validate and adjust amounts** based on historical typical amounts for each vendor
5. Upload ALL receipts to Emburse eWallet (batch via email)
6. Wait for all receipts to appear in eWallet
7. Navigate to report ONCE, select all relevant receipts, add to report
8. Process each line item sequentially in the UI (fill fields, save)
9. **Add attendees if expenses match calendar events**

**Key Intelligence Features:**
- **Batch processing** - Handles all receipts in one session
- **Vendor-agnostic recategorization** - Uses historical profile to correct ANY vendor miscategorization, not just specific carriers
- **Amount validation for any recurring expense** - Compares against historical typical amounts regardless of vendor
- Calendar event matching for attendee population

## Tools Required

- Read tool (for reading receipt images)
- Skill: emburse-expenses (for API documentation - use resources/line-items-api.md for attendees)
- Chrome DevTools MCP (for executing authenticated API calls)

## CRITICAL RULES

### Rule 1: USE HISTORICAL PROFILE FOR RECATEGORIZATION (VENDOR-AGNOSTIC)
- If vendor matches ANY known vendor in `vendor_category_map`, use that historical category
- This applies to ALL vendors, not just specific carriers or gyms
- Example: If user's history shows "Spectrum" is INTERNETWIFI, use that even if OCR says CELLPHONE
- Example: If user's history shows "AT&T" is CELLPHONE, use that even if OCR says INTERNETWIFI
- **Historical category mapping ALWAYS takes precedence over OCR-detected category**

### Rule 2: VALIDATE AMOUNTS AGAINST HISTORY (FOR ANY CATEGORY)
- For ANY vendor with a `typical_amount` in historical profile, compare receipt amount
- If significantly different (>50% variance), flag for user review
- This applies to ALL policy-limited categories (CELLPHONE, INTERNETWIFI, FITNESS)
- For CELLPHONE: if amount >> typical, might be family plan (only single line reimbursable)
- For INTERNETWIFI: if amount >> $50 policy limit, cap at $50
- For FITNESS: if amount >> typical, verify it's personal membership only

### Rule 3: ADD ATTENDEES FOR CALENDAR-MATCHED EXPENSES
- If expense matches a calendar event with external attendees, add them to the line item
- Use data from `calendar_external_meetings` in the expense inventory
- See emburse-expenses resources/line-items-api.md for attendee format

### Rule 4: READ IMAGE FIRST
- Use the Read tool to view the receipt image
- Extract all relevant information before making any API calls
- Claude is multimodal - it can analyze images directly

## Input Parameters

When invoking this agent, provide ALL receipts in a single invocation:

```yaml
report_id: <expense_report_id>

user_info:
  personId: <personId>
  customerId: 3035

allocation:
  matterId: <matterId>
  matterUniqueId: "<code>_<subcode>"
  clientName: "FE Direct - Emerging"

# From historical-profile-builder (CRITICAL for recategorization)
# NOTE: These are USER-SPECIFIC - built from their actual expense history
historical_context:
  # Maps ANY vendor the user has historically expensed to its correct category
  vendor_category_map:
    # Examples - actual values come from user's 6-month history
    "Verizon": CELLPHONE      # Could be AT&T, T-Mobile, etc. for other users
    "Xfinity": INTERNETWIFI   # Could be Spectrum, Comcast, etc. for other users
    "YMCA": FITNESS           # Could be OrangeTheory, Planet Fitness, etc.
    "Uber": RIDESHARE
  # Typical amounts for recurring expenses - used for validation
  recurring_monthly:
    cellular:
      vendor: Verizon         # Whatever carrier the user has
      typical_amount: 45.00   # User's typical single-line amount
    wifi:
      vendor: Xfinity         # Whatever ISP the user has
      typical_amount: 51.54   # User's typical bill
    fitness:
      - vendor: YMCA          # Whatever gym(s) the user has
        typical_amount: 55.00

# ALL receipts to process (from receipt-analyzer results)
receipts:
  - path: /path/to/receipt1.jpg
    vendor_hint: Verizon        # From receipt-analyzer
    amount_hint: 80.00          # From receipt-analyzer
    category_hint: CELLPHONE    # From receipt-analyzer
    calendar_match: null        # Or event details if applicable

  - path: /path/to/receipt2.png
    vendor_hint: Uber
    amount_hint: 45.00
    category_hint: RIDESHARE
    calendar_match:             # From expense-identifier if this matches a calendar event
      event_title: "NYC Trip"
      date: 2026-01-15
      location: "JFK Airport"
      internal_attendees:
        - name: Brandon Kvarda
          email: brandon.kvarda@databricks.com
      external_attendees: []

  - path: /path/to/receipt3.pdf
    vendor_hint: Blue Bottle Coffee
    amount_hint: 125.00
    category_hint: BUSINESSMEALEXT
    calendar_match:
      event_title: "Q1 Planning Dinner - Acme Corp"
      date: 2026-01-15
      location: "Blue Bottle Coffee, San Francisco"
      internal_attendees:
        - name: Brandon Kvarda
          email: brandon.kvarda@databricks.com
      external_attendees:
        - name: Jane Doe
          email: jane.doe@acme.com
          company: Acme Corp
```

## Workflow

**IMPORTANT API LIMITATION:** The Emburse API endpoint for creating line items (`POST /apollo/expenseReports/{reportId}/lineItems/`) returns 500 errors. This is a known issue with the API. **You MUST use the UI-based approach via Chrome DevTools MCP to add line items to reports.**

**WORKFLOW OVERVIEW:**
```
┌────────────────────────────────────────────────────────────────┐
│  Phase A: ANALYZE ALL RECEIPTS (Sequential)                    │
│  For each receipt: Read image → Extract data → Validate        │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│  Phase B: UPLOAD ALL RECEIPTS TO EWALLET (Batch)               │
│  Send all receipts via email → Wait for all to appear          │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│  Phase C: UI AUTOMATION (Sequential, One Browser Session)      │
│  Navigate to report → Open eWallet → Select all → Add to report│
│  For each line item: Fill required fields → Save               │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│  Phase D: RETURN RESULTS FOR ALL RECEIPTS                      │
└────────────────────────────────────────────────────────────────┘
```

---

## Phase A: Analyze All Receipts

### Step 1: Read and Analyze Each Receipt Image

**Process each receipt sequentially.** For each receipt in the `receipts` list:

Use the Read tool to view the receipt:

```
Read the image at: <receipt.path>
```

Extract from the receipt:
- **Vendor/Merchant name**: Who issued the receipt
- **Date**: Transaction date (format: YYYY-MM-DD)
- **Amount**: Total amount (numeric, e.g., 51.54)
- **Currency**: Usually USD
- **Initial category hint**: What type of expense this appears to be

**Compare extracted data against the hints provided:**
- If `vendor_hint`, `amount_hint`, `category_hint` were provided from receipt-analyzer, verify they match
- If discrepancies, use the data you extract from the image (you're re-analyzing)

### Step 2: Apply Historical Recategorization (For Each Receipt)

**CRITICAL: For each receipt, check if vendor matches ANY vendor in the user's historical profile**

```python
# Logic for recategorization - applies to ANY vendor
extracted_vendor = "AT&T Wireless"  # From receipt (could be any carrier/vendor)
ocr_category = "INTERNETWIFI"  # What OCR might incorrectly guess

# Check vendor_category_map from user's historical profile
for known_vendor, correct_category in vendor_category_map.items():
    if known_vendor.lower() in extracted_vendor.lower():
        final_category = correct_category  # Use historical category
        recategorized = True
        break

# If vendor not in history, fall back to OCR category
if not recategorized:
    final_category = ocr_category
```

**Example Recategorizations (vendor-agnostic - depends on user's history):**
| Extracted Vendor | OCR Guess | User's History Says | Use |
|------------------|-----------|---------------------|-----|
| AT&T Wireless | INTERNETWIFI | CELLPHONE | CELLPHONE |
| Spectrum Internet | CELLPHONE | INTERNETWIFI | INTERNETWIFI |
| Planet Fitness | CONFSEM | FITNESS | FITNESS |
| T-Mobile | INTERNETWIFI | CELLPHONE | CELLPHONE |
| Comcast | CELLPHONE | INTERNETWIFI | INTERNETWIFI |

**Key Point:** The mapping comes from the user's actual expense history, not hardcoded vendor lists. If user A has AT&T for cellular and Spectrum for internet, that's what their map shows. User B might have Verizon for cellular and Xfinity for internet.

### Step 3: Validate Amount Against History (For Each Receipt)

For each receipt, compare extracted amount to the user's historical typical amount for that vendor/category:

```python
extracted_amount = 150.00
# Look up typical_amount from user's historical profile for this vendor
typical_amount = historical_context['recurring_monthly'][category]['typical_amount']

if typical_amount:
    variance = abs(extracted_amount - typical_amount) / typical_amount

    if variance > 0.5:  # >50% different from user's typical
        flag_for_review = True
        warning = f"Amount ${extracted_amount} significantly differs from your typical ${typical_amount}"
```

**Amount Validation Applies to ALL Policy-Limited Categories:**
| Category | User's Typical | Receipt Shows | Flag |
|----------|----------------|---------------|------|
| CELLPHONE | User's typical single-line | 3x typical | "May include family plan - only single line reimbursable" |
| FITNESS | User's typical membership | > $250 | "Exceeds $250/month policy limit" |
| INTERNETWIFI | User's typical bill | > $50 | "Exceeds $50/month policy limit" |

**Key Point:** The typical amounts come from the user's own history, not hardcoded values. If one user's cellular is typically $45 and another's is $65, each gets validated against their own typical.

### Step 4: Determine Final Category (For Each Receipt)

**Priority order for category determination for each receipt:**

1. **Historical profile first** - If vendor is in user's `vendor_category_map`, use that category
2. **Fall back to OCR** - If vendor not in history, use what OCR detected
3. **Context clues** - If external attendees, use BUSINESSMEALEXT

The vendor_category_map is user-specific and built from their 6 months of expense history. There's no hardcoded list of vendors - it's whatever the user has actually expensed.

### Step 5: Validate Against Expense Rules (For Each Receipt)

For each receipt, check for policy compliance (applies to ALL vendors in these categories):

```yaml
rules:
  FITNESS:
    monthly_max: 250.00
    warning: "Fitness expenses cannot exceed $250/month"
  INTERNETWIFI:
    monthly_max: 50.00
    warning: "WiFi reimbursement is capped at $50/month"
    action: "Cap at $50.00 if receipt exceeds"
  CELLPHONE:
    policy: "Single line only - no family plans or additional lines"
    warning: "Only personal phone line is reimbursable"
    action: "Use user's typical_amount if receipt seems too high (likely family plan)"
```

**Amount Adjustment Logic (applies to ANY carrier/vendor):**
- For CELLPHONE: If receipt amount > 2x user's typical, likely includes family plan
  - Use `typical_amount` from user's history instead of receipt amount
  - Add note explaining the adjustment
- For INTERNETWIFI: If receipt > $50 policy limit, cap at $50
- For FITNESS: If receipt > $250 policy limit, flag for review

**After analyzing all receipts, you should have a list of processed receipt data:**

```yaml
analyzed_receipts:
  - path: /path/to/receipt1.jpg
    vendor: Verizon
    amount: 80.00
    date: 2026-01-15
    final_category: CELLPHONE
    recategorized: false
    amount_adjusted: false
    calendar_match: null

  - path: /path/to/receipt2.png
    vendor: Uber
    amount: 45.00
    date: 2026-01-10
    final_category: RIDESHARE
    recategorized: false
    amount_adjusted: false
    calendar_match: "NYC Trip"

  # ... etc for all receipts
```

---

## Phase B: Upload All Receipts to eWallet

### Step 6: Batch Upload All Receipts

**ALWAYS use email-based upload.** The API upload requires httpOnly cookies that cannot be accessed programmatically.

**Upload ALL receipts in a batch** (send emails rapidly, they'll be processed in parallel):

```bash
# For EACH receipt, send via email
for receipt in analyzed_receipts:
    python3 ~/.claude/plugins/cache/fe-vibe/fe-google-tools/*/skills/gmail/resources/gmail_builder.py send \
      --to "receipt@ca1.chromeriver.com" \
      --subject "<receipt.amount> USD" \
      --body "#note <receipt.vendor> - <receipt.date> - <receipt.final_category>" \
      --attachment "<receipt.path>"
```

**Wait 30-60 seconds** for ALL receipts to appear in eWallet, then verify:

```javascript
// Check eWallet for all receipts
const transactions = await fetch('/apollo/v2/expenseTransactions?status=ACTIVE&personId=<personId>&feedTypeId=3', {
  headers: { /* standard headers */ }
}).then(r => r.json());

// Verify each uploaded receipt appears
const found = [];
for (const receipt of analyzed_receipts) {
  const match = transactions.find(t =>
    t.vendorName?.toLowerCase().includes(receipt.vendor.toLowerCase()) &&
    Math.abs(t.amount - receipt.amount) < 0.01
  );
  if (match) {
    found.push({ receipt, transactionId: match.transactionId });
  }
}

// If not all found, wait another 30 seconds and retry
```

---

## Phase C: UI Automation (Single Browser Session)

### Step 7: Add All Line Items via UI (REQUIRED - API Returns 500 Errors)

**CRITICAL: The direct API POST to `/apollo/expenseReports/{reportId}/lineItems/` returns 500 errors. You MUST use the UI-based approach via Chrome DevTools MCP.**

**This entire section uses ONE browser session to process ALL receipts.**

**SEQUENTIAL ADD FLOW OVERVIEW:**
```
┌─────────────────────────────────────────────────────────────────┐
│  1. Navigate to report → Click "Add New Expense"                │
│     Opens the eWallet panel                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. Click "Select All Transactions" checkbox                    │
│     All eWallet items become selected                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. Click "Add Selected Transactions to Report"                 │
│     Triggers SEQUENTIAL form flow for each expense              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. FOR EACH EXPENSE (automatic sequential flow):               │
│     a. Form appears with expense type selector OR edit form     │
│     b. Select/change category if needed (click category button) │
│     c. Modify amount in "Spent" field if needed                 │
│     d. Fill category-specific required fields                   │
│     e. Click Save → AUTOMATICALLY advances to next expense      │
│     f. Repeat until all expenses processed                      │
└─────────────────────────────────────────────────────────────────┘
```

#### 7a. Navigate to the Report (Once)

```bash
mcp-cli call chrome-devtools/navigate_page '{"type": "url", "url": "https://app.ca1.chromeriver.com/index#expense/draft/<report_id>/details"}'
```

#### 7b. Open eWallet Panel

```bash
# Take snapshot to find "Add New Expense" button
mcp-cli call chrome-devtools/take_snapshot '{}'

# Click "Add New Expense" button to open eWallet panel
# Look for: button "Add New Expense"
mcp-cli call chrome-devtools/click '{"uid": "<add-new-expense-button-uid>"}'

# Take another snapshot to see the eWallet items
mcp-cli call chrome-devtools/take_snapshot '{}'
```

#### 7c. Select ALL Receipts from eWallet

**IMPORTANT:** Click the "Select All Transactions" checkbox to select all items at once.

```bash
# Find the "Select All Transactions" checkbox in the eWallet panel
# Look for: checkbox "Select All Transactions"
mcp-cli call chrome-devtools/click '{"uid": "<select-all-checkbox-uid>"}'

# Verify all items are now checked (checkboxes show "check_box" not "check_box_outline_blank")
mcp-cli call chrome-devtools/take_snapshot '{}'
```

#### 7d. Start the Sequential Add Flow

**This is the key step.** Clicking this button triggers the sequential form flow.

```bash
# Click "Add Selected Transactions to Report" button
# Look for: button "Add Selected Transactions to Report"
mcp-cli call chrome-devtools/click '{"uid": "<add-selected-button-uid>"}'

# The UI will now show a form for the FIRST expense
# Take snapshot to see what form appeared
mcp-cli call chrome-devtools/take_snapshot '{}'
```

#### 7e. Process Each Expense in the Sequential Flow

**After clicking "Add Selected Transactions to Report", the UI automatically presents each expense one at a time.** For each expense:

1. **A form appears** - either an expense type selector or an edit form
2. **Select/change category** if needed (click the expense type button)
3. **Modify the amount** in the "Spent" field if needed
4. **Fill required fields** for that category
5. **Click Save** → automatically advances to the next expense

**CRITICAL: Use `fill` tool for ALL dropdowns and text fields - NOT `click` on options!**

```bash
# WRONG - clicking dropdown options often fails or times out
mcp-cli call chrome-devtools/click '{"uid": "<option-uid>"}'  # May timeout!

# CORRECT - use fill tool on the combobox element
mcp-cli call chrome-devtools/fill '{"uid": "<combobox-uid>", "value": "Subscription"}'
```

**Processing Each Expense:**

```bash
# === For EACH expense in the sequential flow ===

# 1. Take snapshot to see current form state
mcp-cli call chrome-devtools/take_snapshot '{}'

# 2. Check if expense type selection is needed
#    Look for: heading "Select Valid Expense Type"
#    If this appears, the category couldn't be auto-detected

# 3a. If "Select Valid Expense Type" dialog appears:
#     Click the correct expense type button
#     For Anthropic subscriptions → Click "Career Development"
#     For Verizon → Already "Mobile/Cellphone MobSec" (may not need change)
#     For Xfinity → Already "Internet / WiFi (Home)" (may not need change)
#
#     Look for buttons like:
#     - button "Career Development" description="Career Development"
#     - button "Telecom" description="Telecom" (then select sub-type)
mcp-cli call chrome-devtools/click '{"uid": "<expense-type-button-uid>"}'

# 3b. Take snapshot to see the full expense form
mcp-cli call chrome-devtools/take_snapshot '{}'

# 4. Modify the AMOUNT if needed
#    Look for: textbox "Spent" value="175.62"
#    For Verizon: Change from full bill to single-line amount
#    For Xfinity: Change to policy max if exceeds $50
mcp-cli call chrome-devtools/fill '{"uid": "<spent-textbox-uid>", "value": "87.81"}'

# 5. Fill CATEGORY-SPECIFIC required fields
#    Different expense types have different required fields:
#
#    Career Development → requires "Learning Detail" dropdown
mcp-cli call chrome-devtools/fill '{"uid": "<learning-detail-combobox-uid>", "value": "Subscription"}'
#
#    Mobile/Cellphone MobSec → allocation only (usually pre-filled)
#
#    Internet/WiFi → allocation only (usually pre-filled)

# 6. Verify allocation is set (usually pre-filled)
#    Look for: combobox "Allocation Search" value="651 FE Direct - Emerging Cost Center"
#    If empty ("-- Select --"), fill it:
mcp-cli call chrome-devtools/fill '{"uid": "<allocation-combobox-uid>", "value": "651 FE Direct"}'

# 7. SAVE the expense - this advances to the next one
#    Look for: button "Save"
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'

# 8. Wait briefly for UI to update, then take snapshot for next expense
sleep 2
mcp-cli call chrome-devtools/take_snapshot '{}'

# === Repeat steps 1-8 for each expense until all are processed ===
```

**Expense-Type Specific Required Fields:**

| Expense Type | Required Field | How to Fill |
|--------------|----------------|-------------|
| Career Development | Learning Detail | `fill` with: "Books", "Certification", "Conference", "Online Learning", "Subscription", "University Course" |
| Professional Membership | Membership Type | `fill` with: "License/ permits" or "Professional Membership Fee" |
| Business Meal (External) | Business Purpose | `fill` with text describing the purpose |
| Mobile/Cellphone MobSec | None beyond standard | Just allocation (usually pre-filled) |
| Internet/WiFi (Home) | None beyond standard | Just allocation (usually pre-filled) |
| Fitness | None beyond standard | Just allocation |

**Amount Adjustments During Sequential Flow:**

| Expense Type | Condition | Action |
|--------------|-----------|--------|
| Mobile/Cellphone | Receipt shows family plan amount | Fill "Spent" with single-line amount from historical profile |
| Internet/WiFi | Receipt exceeds $50 policy | Fill "Spent" with "50.00" |
| Any | Amount significantly different from historical typical | Fill with corrected amount |

#### 7f. Verify All Line Items Were Added

After the sequential flow completes (no more expense forms appear):

```bash
# Take final snapshot to see all line items in the report
mcp-cli call chrome-devtools/take_snapshot '{}'

# Verify:
# - Total Pay Me Amount reflects all added expenses
# - Each expense appears as a line item in the report
# - Line items show correct amounts and categories
```

**UI Elements to Look For:**
| Element | Typical Pattern | Description |
|---------|-----------------|-------------|
| Add New Expense | button "Add New Expense" | Opens eWallet panel |
| Select All | checkbox "Select All Transactions" | Selects all eWallet items |
| Add Selected | button "Add Selected Transactions to Report" | Starts sequential add flow |
| Expense Type | heading "Select Valid Expense Type" | Category selection needed |
| Category buttons | button "Career Development", etc. | Click to select category |
| Spent field | textbox "Spent" value="XX.XX" | Edit amount here |
| Learning Detail | combobox "Learning Detail" | Required for Career Development |
| Allocation | combobox "Allocation Search" | Cost center (usually pre-filled) |
| Save | button "Save" | Saves and advances to next |
| Cancel | button "Cancel" | Cancels current expense |
| Total Pay Me | heading "Total Pay Me Amount XXX.XX USD" | Running total |

**Common Expense-Type Required Fields:**
| Expense Type | Required Field | Valid Values |
|--------------|----------------|--------------|
| Career Development | Learning Detail | "Books", "Certification", "Conference", "Online Learning", "Subscription", "University Course" |
| Professional Membership Dues | Professional Membership Fee | "License/ permits", "Professional Membership Fee" |
| Business Meal (External) | Business Purpose | Free text |
| Business Meal (External) | Attendees | Must add at least one external attendee |

---

### Step 7g: Editing Existing Line Items (Category or Amount Changes)

**IMPORTANT:** To modify a line item in place (including changing its category), you MUST enter edit mode FIRST by clicking the Edit button.

**To change an amount (modifies existing):**

```bash
# 1. Click on the line item to select it
mcp-cli call chrome-devtools/click '{"uid": "<line-item-tab-uid>"}'

# 2. Click Edit button to enable edit mode
# Look for: button "Edit" in "Line Item Action Bar" region
mcp-cli call chrome-devtools/click '{"uid": "<edit-button-uid>"}'

# 3. Fields are now editable (no longer show "disableable disabled")
# Use fill tool on the Spent field
mcp-cli call chrome-devtools/fill '{"uid": "<spent-textbox-uid>", "value": "150.00"}'

# 4. Save changes
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'
```

**To change an expense category (modifies existing IN PLACE):**

```bash
# 1. Click on the line item
mcp-cli call chrome-devtools/click '{"uid": "<line-item-tab-uid>"}'

# 2. CRITICAL: Enter Edit mode FIRST
# Look for: button "Edit" in "Line Item Action Bar" region
mcp-cli call chrome-devtools/click '{"uid": "<edit-button-uid>"}'

# 3. NOW click "Edit expense item type" (icon next to category heading)
# Look for: generic "Edit expense item type"
mcp-cli call chrome-devtools/click '{"uid": "<edit-type-uid>"}'

# 4. Expense type selection dialog appears - click desired category
mcp-cli call chrome-devtools/click '{"uid": "<category-button-uid>"}'

# 5. Fill the new expense type's form (amount is preserved!)
# Fill any category-specific required fields
mcp-cli call chrome-devtools/fill '{"uid": "<required-dropdown-uid>", "value": "Required Value"}'
mcp-cli call chrome-devtools/fill '{"uid": "<merchant-field-uid>", "value": "Vendor Name"}'

# 6. Save - this modifies the SAME line item (same ID preserved)
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'
```

**Form States to Recognize:**

| State | Field Attributes | Action Needed |
|-------|------------------|---------------|
| View mode | `disableable disabled` | Click Edit button first |
| Edit mode | No disabled attribute, `focusable` | Can fill directly |
| Validation error | `invalid=true` | Fill required field |

---

### Step 8: Add Attendees for Calendar-Matched Expenses

**For expenses that match calendar events with external attendees:**

After the basic line item is saved, you may need to edit it to add attendees:

1. Click on the saved line item to open edit mode
2. Find the attendees section
3. Add internal and external attendees
4. Save again

```javascript
// Click on the line item row to edit
await chrome_devtools.click({ uid: "<line item row uid>" });

// Find and fill attendee fields
// Internal attendees
await chrome_devtools.fill({
  uid: "<internal attendee field uid>",
  value: receipt.calendar_match.internal_attendees[0].name
});

// External attendees
await chrome_devtools.fill({
  uid: "<external attendee field uid>",
  value: receipt.calendar_match.external_attendees[0].name
});
await chrome_devtools.fill({
  uid: "<external company field uid>",
  value: receipt.calendar_match.external_attendees[0].company
});

// Save
await chrome_devtools.click({ uid: "<Save button uid>" });
```

---

## Phase D: Return Results

### Step 9: Return Results for All Receipts

```yaml
overall_status: success  # 'success' if all processed, 'partial' if some failed, 'error' if none processed
report_id: "<reportId>"
total_receipts: 3
successful: 3
failed: 0

# Summary for quick review
summary:
  total_amount: 250.00
  categories:
    CELLPHONE: 1
    RIDESHARE: 1
    BUSINESSMEALEXT: 1
  recategorized_count: 0
  amount_adjusted_count: 1
  attendees_added_count: 1

# Detailed results for each receipt
receipts:
  - status: success
    path: /path/to/receipt1.jpg
    extracted_data:
      vendor: Verizon
      amount: 80.00
      date: 2026-01-15
      currency: USD
    recategorization:
      applied: false
    amount_adjustment:
      applied: false
    final_expense:
      category: CELLPHONE
      category_display: "Cell Phone"
      amount: 80.00
      vendor: Verizon
    policy_check:
      compliant: true
      warnings: []
    calendar_match:
      matched: false
    attendees_added:
      internal: 0
      external: 0
    ewallet:
      transaction_id: 178905836
      upload_method: email

  - status: success
    path: /path/to/receipt2.png
    extracted_data:
      vendor: Uber
      amount: 45.00
      date: 2026-01-10
      currency: USD
    recategorization:
      applied: false
    amount_adjustment:
      applied: false
    final_expense:
      category: RIDESHARE
      amount: 45.00
      vendor: Uber
    policy_check:
      compliant: true
      warnings: []
    calendar_match:
      matched: true
      event: "NYC Trip"
    attendees_added:
      internal: 0
      external: 0
    ewallet:
      transaction_id: 178905837
      upload_method: email

  - status: success
    path: /path/to/receipt3.pdf
    extracted_data:
      vendor: Blue Bottle Coffee
      amount: 125.00
      date: 2026-01-15
      currency: USD
    recategorization:
      applied: false
    amount_adjustment:
      applied: false
    final_expense:
      category: BUSINESSMEALEXT
      category_display: "Business Meal (External)"
      amount: 125.00
      vendor: Blue Bottle Coffee
    policy_check:
      compliant: true
      warnings: []
    calendar_match:
      matched: true
      event: "Q1 Planning Dinner - Acme Corp"
    attendees_added:
      internal: 1
      external: 1
    ewallet:
      transaction_id: 178905838
      upload_method: email

# Any errors encountered
errors: []

# Policy warnings that need user attention
policy_warnings:
  - receipt: /path/to/receipt4.jpg
    warning: "WiFi expense exceeds $50 limit - capped at $50"

notes: "All 3 receipts processed successfully. 1 expense had attendees added from calendar match."
```

## Category Quick Reference

| Code | Display Name | Monthly Limit | Amount Adjustment Notes |
|------|--------------|---------------|-------------------------|
| INTERNETWIFI | Internet / WiFi (Home) | $50 | Cap at $50 if exceeds |
| CELLPHONE | Cell Phone | N/A | Use user's typical if receipt >> typical (family plan) |
| FITNESS | Fitness | $250 | Flag if exceeds limit |
| CONFSEM | Conference/Seminar | N/A | - |
| RIDESHARE | Rideshare | N/A | - |
| BUSINESSMEALEXT | Business Meal (External) | N/A | Requires external attendees |
| BUSINESSMEAL | Business Meal | N/A | Internal only |

**Note:** Recategorization is based entirely on the user's historical profile, not on vendor names. Any vendor can be in any category - it depends on what the user has historically expensed.

## Error Handling

| Situation | Action |
|-----------|--------|
| Cannot read one image | Log error for that receipt, continue with others |
| Cannot extract amount | Use historical typical_amount if available, or hint from receipt-analyzer |
| Vendor not in history | Use OCR category or category_hint as fallback |
| Calendar match unclear | Skip attendees, note in response |
| API upload fails | Fall back to email upload |
| Some receipts not in eWallet | Wait and retry; if still missing, process available ones |
| Allocation not pre-filled | Use `fill` tool on allocation combobox |
| Save button disabled | Check for required fields not filled (look for `invalid=true`) |
| UI element not found | Take new snapshot and search for correct UID |
| One line item fails to save | Log error, continue with next line item |
| **Dropdown click fails/times out** | **Use `fill` tool instead of `click` on options** |
| **Click on dropdown option returns but no selection** | **Use `fill` tool with combobox UID and value text** |
| **Fields show `disableable disabled`** | **Click Edit button first to enable editing** |
| **Validation error on dropdown** | **Dropdown shows `invalid=true` - use `fill` to select valid option** |

**Partial Success Handling:**
- If some receipts fail but others succeed, return `overall_status: partial`
- Include details of what succeeded and what failed
- The user can address failures manually or re-run for just the failed receipts

## WHAT NOT TO DO

- **DO NOT spawn multiple instances of this agent** - Chrome DevTools MCP uses one browser
- **DO NOT process receipts in parallel** - UI automation must be sequential
- **DO NOT use `click` on dropdown options** - Use `fill` tool on the combobox element instead
- **DO NOT try to modify fields without clicking Edit first** - Fields are disabled until Edit mode
- **DO NOT click "Edit expense item type" without entering Edit mode first** - Click Edit button first, then change category
- DO NOT ignore historical profile - it's critical for accurate categorization
- DO NOT use OCR category if historical data says otherwise for that vendor
- DO NOT accept obviously wrong amounts without flagging (use user's typical as baseline)
- DO NOT hardcode vendor-to-category mappings - always use user's historical profile
- DO NOT skip attendees when calendar event is provided
- DO NOT submit the report - only add line items

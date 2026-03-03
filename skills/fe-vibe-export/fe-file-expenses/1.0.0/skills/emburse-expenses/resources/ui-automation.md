# Chrome DevTools UI Automation

This document covers UI automation patterns for Emburse ChromeRiver using Chrome DevTools MCP. Use these patterns when the REST API approach is insufficient or when interacting with complex UI workflows.

## When to Use UI Automation

| Scenario | Recommended Approach |
|----------|---------------------|
| Creating reports | API (faster, more reliable) |
| Adding line items from eWallet | UI (handles complex form flows) |
| Changing expense category | UI (API approach is complex) |
| Modifying amounts | Both work (UI is simpler) |
| Filling dropdowns | UI with `fill` tool |

## Prerequisites

- Chrome DevTools MCP server must be connected
- User must be authenticated to Emburse (Okta SSO completed)
- Navigate to the report page before automation

## Key MCP Tools

| Tool | Purpose |
|------|---------|
| `take_snapshot` | Get current page state and element UIDs |
| `click` | Click buttons and select elements |
| `fill` | Fill text fields and select dropdown values |
| `press_key` | Send keyboard input |
| `navigate_page` | Navigate to URLs |

## Editing Line Items

### 1. Navigate to Report

```bash
mcp-cli call chrome-devtools/navigate_page '{"url": "https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details"}'
```

### 2. Select a Line Item

Take a snapshot to find line item UIDs:

```bash
mcp-cli call chrome-devtools/take_snapshot '{}'
```

Line items appear as `tab` elements:
```
uid=X_38 tab " 11/10/2025, Career Development, SPENT 220.4 USD, PAY ME 220.4, Validated "
```

Click to select:
```bash
mcp-cli call chrome-devtools/click '{"uid": "<line-item-uid>"}'
```

### 3. Enable Edit Mode

Click the "Edit" button in the Line Item Action Bar:

```bash
# Find the Edit button UID from snapshot (usually in "Line Item Action Bar" region)
mcp-cli call chrome-devtools/click '{"uid": "<edit-button-uid>"}'
```

When edit mode is active:
- Cancel and Save buttons appear in navigation
- Form fields change from `disableable disabled` to editable
- The "Edit expense item type" icon becomes active

### 4. Modify Amount

Use the `fill` tool on the Spent textbox:

```bash
# Find Spent field UID (look for: textbox "Spent" value="220.40")
mcp-cli call chrome-devtools/fill '{"uid": "<spent-field-uid>", "value": "150.00"}'
```

### 5. Save Changes

Click the Save button:

```bash
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'
```

## Changing Expense Category

**IMPORTANT:** To modify the expense type in place (not create a new line item), you MUST enter edit mode FIRST by clicking the Edit button, THEN click "Edit expense item type".

### 1. Select the Line Item

```bash
mcp-cli call chrome-devtools/click '{"uid": "<line-item-uid>"}'
```

### 2. Enter Edit Mode FIRST

**This is critical!** Click the "Edit" button in the Line Item Action Bar before changing the category:

```bash
mcp-cli call chrome-devtools/click '{"uid": "<edit-button-uid>"}'
```

### 3. Click "Edit expense item type"

Look for: `generic "Edit expense item type"` in the snapshot.

```bash
mcp-cli call chrome-devtools/click '{"uid": "<edit-type-uid>"}'
```

### 4. Select New Category

The expense type selection dialog appears with category buttons:
```
button "Career Development" focusable
button "Fitness" focusable
button "Ground Transportation" focusable
...
```

Click the desired category:

```bash
mcp-cli call chrome-devtools/click '{"uid": "<fitness-button-uid>"}'
```

### 5. Fill Category-Specific Fields

Different expense types require different fields. Take a snapshot to see the form.

### 6. Fill Required Fields and Save

```bash
# Fill amount
mcp-cli call chrome-devtools/fill '{"uid": "<spent-field-uid>", "value": "100.00"}'

# Click Save
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'
```

## Filling Dropdowns (Angular Material)

**CRITICAL:** Use the `fill` tool for dropdown selection, NOT `click`. The Angular Material dropdowns don't respond reliably to click events on individual options.

### Example: Learning Detail Dropdown

```bash
# WRONG - clicking options often fails
mcp-cli call chrome-devtools/click '{"uid": "<option-uid>"}'  # May timeout or not select

# CORRECT - use fill tool
mcp-cli call chrome-devtools/fill '{"uid": "<combobox-uid>", "value": "Subscription"}'
```

### Finding the Combobox UID

Look for elements like:
```
combobox "Learning Detail" expandable haspopup="menu" value="-- Select --"
```

Use the combobox UID (not the option UIDs inside it).

## Adding Multiple Line Items from eWallet (Sequential Flow)

**RECOMMENDED APPROACH:** Select all receipts at once and use the sequential add flow. This is the most reliable method for adding multiple expenses.

### Overview

When you select multiple receipts from eWallet and click "Add Selected Transactions to Report", ChromeRiver presents a **sequential form flow** where each expense appears one at a time. You edit each expense (category, amount, required fields), click Save, and it automatically advances to the next expense.

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Open eWallet → Select All Transactions                      │
│  2. Click "Add Selected Transactions to Report"                 │
│  3. FOR EACH expense:                                           │
│     - Select/change category if needed                          │
│     - Modify amount if needed                                   │
│     - Fill required fields                                      │
│     - Save → automatically advances to next                     │
│  4. Repeat until all expenses processed                         │
└─────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Workflow

#### 1. Navigate to Report

```bash
mcp-cli call chrome-devtools/navigate_page '{"type": "url", "url": "https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details"}'
```

#### 2. Open eWallet Panel

```bash
# Take snapshot to find "Add New Expense" button
mcp-cli call chrome-devtools/take_snapshot '{}'

# Click "Add New Expense" button
# Look for: button "Add New Expense"
mcp-cli call chrome-devtools/click '{"uid": "<add-new-expense-uid>"}'
```

#### 3. Select All Transactions

```bash
# Take snapshot to see eWallet items
mcp-cli call chrome-devtools/take_snapshot '{}'

# Click "Select All Transactions" checkbox
# Look for: checkbox "Select All Transactions"
mcp-cli call chrome-devtools/click '{"uid": "<select-all-checkbox-uid>"}'

# Verify all items are selected (checkboxes show "check_box" not "check_box_outline_blank")
```

#### 4. Start Sequential Add Flow

```bash
# Click "Add Selected Transactions to Report" button
# Look for: button "Add Selected Transactions to Report"
mcp-cli call chrome-devtools/click '{"uid": "<add-selected-button-uid>"}'

# The UI now shows a form for the FIRST expense
mcp-cli call chrome-devtools/take_snapshot '{}'
```

#### 5. Process Each Expense in Sequence

For each expense, the UI will show either:
- **Expense Type Selection** - heading "Select Valid Expense Type" (if category couldn't be auto-detected)
- **Edit Form** - form with Date, Spent, category-specific fields

**Processing each expense:**

```bash
# === EXPENSE 1 ===
# Take snapshot to see current form
mcp-cli call chrome-devtools/take_snapshot '{}'

# If "Select Valid Expense Type" appears, click the correct category
# Look for: button "Career Development" or button "Mobile/Cellphone MobSec"
mcp-cli call chrome-devtools/click '{"uid": "<category-button-uid>"}'

# Take snapshot to see full form
mcp-cli call chrome-devtools/take_snapshot '{}'

# Modify amount if needed (e.g., change family plan amount to single-line)
# Look for: textbox "Spent" value="175.62"
mcp-cli call chrome-devtools/fill '{"uid": "<spent-uid>", "value": "87.81"}'

# Fill category-specific required fields
# Career Development → Learning Detail
mcp-cli call chrome-devtools/fill '{"uid": "<learning-detail-uid>", "value": "Subscription"}'

# Save - advances to next expense
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'

# Wait for UI to update
sleep 2

# === EXPENSE 2 ===
mcp-cli call chrome-devtools/take_snapshot '{}'
# ... repeat process for each expense ...
```

### UI Elements Reference

| Element | Pattern | Description |
|---------|---------|-------------|
| Add New Expense | `button "Add New Expense"` | Opens eWallet panel |
| Select All | `checkbox "Select All Transactions"` | Selects all eWallet items |
| Checkbox selected | `checkbox "..." checked` or text `check_box` | Item is selected |
| Checkbox unselected | text `check_box_outline_blank` | Item not selected |
| Add Selected | `button "Add Selected Transactions to Report"` | Starts sequential flow |
| Category Needed | `heading "Select Valid Expense Type"` | Must select category |
| Category button | `button "Career Development"`, etc. | Click to select |
| Spent field | `textbox "Spent" value="XX.XX"` | Amount to expense |
| Save | `button "Save"` | Saves and advances |
| Cancel | `button "Cancel"` | Cancels current expense |
| Total | `heading "Total Pay Me Amount XXX.XX USD"` | Running total |

### Category-Specific Required Fields

| Expense Type | Required Field | Fill Value |
|--------------|----------------|------------|
| Career Development | Learning Detail | "Subscription", "Online Learning", "Books", etc. |
| Mobile/Cellphone MobSec | (none beyond allocation) | - |
| Internet/WiFi (Home) | (none beyond allocation) | - |
| Professional Membership | Membership Type | "Professional Membership Fee" |
| Business Meal (External) | Business Purpose | Text description |

### Amount Adjustments

Make amount corrections during the sequential flow:

| Scenario | Action |
|----------|--------|
| Cellular shows family plan ($175) | Fill Spent with single-line amount ($87.81) |
| WiFi exceeds $50 policy | Fill Spent with "50.00" |
| Amount differs from historical typical | Fill with corrected amount |

### Verifying Completion

After all expenses are processed (no more forms appear):

```bash
# Take final snapshot
mcp-cli call chrome-devtools/take_snapshot '{}'

# Verify:
# - "Total Pay Me Amount" reflects sum of all expenses
# - Each expense appears as a line item
# - No more expense edit forms are shown
```

## Form Field States

### Read-Only Mode
```
combobox "Date" disableable disabled expandable haspopup="listbox" required value="12/10/2025"
StaticText "Spent"
StaticText "220.40"
```

### Edit Mode
```
combobox "Date" expandable haspopup="listbox" required value="12/10/2025"
textbox "Spent" value="220.40"
```

The presence of `disableable disabled` indicates the form is in read-only mode. Click "Edit" to enable editing.

## Common Element Patterns

### Line Item List
```
tab " DATE, EXPENSE_TYPE, SPENT X USD, PAY ME X, Status " description="Press Enter to Open Item" selectable
```

### Action Bar Buttons
```
region "Line Item Action Bar"
  button "Images"
  button "Edit"
  button "Delete"
  button "Show More" haspopup="menu"
```

### Save/Cancel Navigation
```
navigation
  button "Cancel"
  button "Save"
```

### Expense Type Heading with Edit Icon
```
generic "Edit expense item type"
heading "Career Development" level="1"
```

## Error Handling

### Element Not Found
If the UID from a previous snapshot is not found:
1. Take a fresh snapshot
2. Find the new UID
3. Retry the action

### Click Timeout
If click times out:
1. Try `fill` tool for input elements
2. Try `press_key` with "Enter" for focused elements
3. Wait and retry

### Form Validation Errors
Look for `invalid=true` on form fields or warning elements:
```
combobox "Learning Detail" invalid expandable haspopup="menu" value="-- Select --"
```

Fill the required field to clear validation.

## Best Practices

1. **Always take a snapshot first** - UIDs change between page loads
2. **Use `fill` for dropdowns** - More reliable than clicking options
3. **Wait between actions** - `sleep 2` before taking verification snapshots
4. **Check for edit mode** - Verify fields are editable before trying to fill
5. **Verify saves** - Take snapshot after save to confirm changes persisted

## Example: Complete Workflow

```bash
# 1. Navigate to report
mcp-cli call chrome-devtools/navigate_page '{"url": "https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details"}'

# 2. Wait and snapshot
sleep 2
mcp-cli call chrome-devtools/take_snapshot '{}'

# 3. Click line item (from snapshot, find the line item tab UID)
mcp-cli call chrome-devtools/click '{"uid": "X_38"}'

# 4. Click Edit button
mcp-cli call chrome-devtools/click '{"uid": "X_79"}'

# 5. Fill amount
mcp-cli call chrome-devtools/fill '{"uid": "X_87", "value": "150.00"}'

# 6. Click Save
mcp-cli call chrome-devtools/click '{"uid": "X_80"}'

# 7. Verify
sleep 3
mcp-cli call chrome-devtools/take_snapshot '{}'
```

## Example: Change Expense Category

This workflow changes a line item's expense type from "Fitness" to "Career Development" **in place** (modifying the existing line item, not creating a new one).

```bash
# 1. Navigate to report
mcp-cli call chrome-devtools/navigate_page '{"url": "https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details"}'

# 2. Wait and snapshot
sleep 2
mcp-cli call chrome-devtools/take_snapshot '{}'

# 3. Click line item (from snapshot, find the line item tab UID)
mcp-cli call chrome-devtools/click '{"uid": "<line-item-uid>"}'

# 4. CRITICAL: Enter Edit mode FIRST
mcp-cli call chrome-devtools/click '{"uid": "<edit-button-uid>"}'

# 5. Wait for edit mode, then click "Edit expense item type"
sleep 1
mcp-cli call chrome-devtools/take_snapshot '{}'
mcp-cli call chrome-devtools/click '{"uid": "<edit-type-uid>"}'  # generic "Edit expense item type"

# 6. Select new category
sleep 1
mcp-cli call chrome-devtools/take_snapshot '{}'
mcp-cli call chrome-devtools/click '{"uid": "<category-button-uid>"}'  # e.g., "Career Development"

# 7. Fill category-specific required fields (e.g., Learning Detail for Career Development)
sleep 1
mcp-cli call chrome-devtools/take_snapshot '{}'
mcp-cli call chrome-devtools/fill '{"uid": "<learning-detail-combobox>", "value": "Subscription"}'
mcp-cli call chrome-devtools/fill '{"uid": "<merchant-field>", "value": "Anthropic PBC"}'

# 8. Save
mcp-cli call chrome-devtools/click '{"uid": "<save-button-uid>"}'

# 9. Verify - same line item ID, category changed, still same number of line items
sleep 3
mcp-cli call chrome-devtools/take_snapshot '{}'
```

**Key Point:** The line item ID in the URL should remain the same throughout, confirming the modification was in-place.

# Vibe Profile

Instructions for configuring and customizing your vibe profile.

## Overview

The vibe profile (`~/.vibe/profile`) stores your personal info, accounts, channels, and preferences. It can be:
- **Auto-generated** from Slack, Salesforce, and Glean data
- **Customized** by adding/removing accounts, channels, contacts, etc.

## Building a Profile

Generate a profile file in YAML format. First, try to infer the inputs using tools/MCPs if available - like Slack and Glean. Use the salesforce-actions skill for anything needed from Salesforce.

## Customizing a Profile

You can customize your profile by asking Claude to make specific changes:

### Example Customization Requests

- "Remove Netflix from my profile"
- "Add the channel #databricks5550 to my Block account"
- "Update my manager to Lee Blackwell"
- "Add Jane Doe to my recent contacts"
- "Remove #old-channel from my profile"

### How Customizations Work

1. The agent reads your existing profile
2. Makes the requested changes
3. Discovers any needed info (e.g., Slack channel IDs)
4. Records the change in the `customizations` section
5. Writes the updated profile

## Profile Structure

```yaml
# Vibe User Profile
# Generated: <timestamp>
# Regenerate by asking Claude to rebuild your vibe profile

user:
  name: Brandon Kvarda  # Discoverable from $USER output
  email: brandon.kvarda@databricks.com  # "$USER@databricks.com"
  username: brandon.kvarda
  role: SA  # One of: SA, SSA, RSA, FE-OTHER
  title: Lead SA (DNB)
  location: Unknown
  manager:
    name: Lee Blackwell
    email: lee.blackwell@databricks.com
  salesforce_user_id: 0053f000000tzcWAAQ
  slack_user_id: U029YEWF7V2
  databricks_user_id: 4511030703487340
  start_date: null
  running_todo_doc_url: https://docs.google.com/foo  # OR create if doesn't exist

accounts:  # Accounts an SA supports (not needed for SSA/RSA)
  - name: Block
    salesforce_account_id: 00161000005eOlMAAU
    use_cases:
      - name: GCP Migration - Square SignalSmith
        salesforce_id: aAv8Y000000YMdESAW
        stage: U5
        status: Yellow
    team:
      account_executive:
        name: Ryan Zapanta
        email: ryan.zapanta@databricks.com
        slack_id: U039LFJM4BS
        title: Sr Digital Native Account Executive
        manager: Brian Bailey
        manager_email: brian.bailey@databricks.com
      dsa:
        name: Beth Gregory
        email: beth.gregory@databricks.com
        slack_id: U06R6JEUP52
        title: Sr. Delivery Solutions Architect
      specialists:
        - name: Xavier Armitage
          email: xavier.armitage@databricks.com
          role: Solution Architect
    internal_running_docs:
      - name: weekly_account_team
        url: https://docs.google.com/foo
        description: Weekly account team standup
    slack_channels:
      external:
        - name: databricks5550
          id: C024LP7P686  # IMPORTANT: Always include channel ID
          last_activity: 2026-01-09
          description: Primary external channel with Block for support
        - name: ext-block-databricks-llm-product-team
          id: C0XXXXXXX
          last_activity: null
          description: External channel specific to LLM/GenAI issues
      internal:
        - name: xyz-account-team
          id: C0XXXXXXX
          last_activity: null
          description: Internal account team updates

recent_contacts:
  - name: Dustin Flores
    slack_id: U03R8R8G41F
    email: dustin.flores@databricks.com
    title: Manager, Emerging Enterprise Sales
    last_interaction: 2026-01-08

# User preferences for plugin behavior
preferences:
  salesforce:
    next_steps_format: short  # "short" or "verbose"
  # Add other plugin preferences here as needed

# Metadata
generated_at: 2026-01-09T22:24:00Z
activity_threshold_days: 14
data_sources:
  - glean
  - salesforce
  - slack

notes:
  - Auto-generated notes about missing data
  - Information that couldn't be discovered

# Manual customizations (audit trail)
customizations:
  - date: 2026-01-09
    action: removed
    type: account
    details: "Removed Netflix account per user request"
  - date: 2026-01-09
    action: added
    type: channel
    details: "Added #new-channel (C0XXXXXXX) to Block external channels"
  - date: 2026-01-10
    action: updated
    type: field
    details: "Updated manager to Lee Blackwell"
```

## Customizations Section

The `customizations` section provides an audit trail of manual changes to your profile. Each entry includes:

| Field | Description |
|-------|-------------|
| `date` | When the change was made (YYYY-MM-DD) |
| `action` | Type of action: `added`, `removed`, or `updated` |
| `type` | What was changed: `account`, `channel`, `contact`, or `field` |
| `details` | Human-readable description of the change |

This helps you track what was manually configured vs. auto-discovered.

## Channel ID Discovery

When adding channels, the agent will automatically discover the Slack channel ID using the Slack MCP. Channel IDs are required for all channel entries (format: `C0XXXXXXX`).

If a channel cannot be found, the agent will ask you to provide the ID manually.

## Preferences Section

The `preferences` section stores user preferences for plugin behavior. Skills check this section to customize their output and behavior. See individual skill documentation for available preferences.

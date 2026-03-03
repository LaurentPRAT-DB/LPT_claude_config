---
name: configure-vibe
description: Configure, setup, and validate the vibe environment including dependencies, directories, and permissions
---

# Configure Vibe Skill

Comprehensive environment setup and validation for vibe Field Engineering toolkit.

## Instructions

### Environment Setup

1) **Install Homebrew** if it doesn't exist:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2) **Install required CLI tools:**
   - Salesforce CLI: `npm install @salesforce/cli --global`
   - Databricks CLI:
     ```bash
     brew tap databricks/tap
     brew install databricks
     ```
   - Atlassian CLI:
     ```bash
     brew tap atlassian/homebrew-acli
     brew install acli
     ```
   - Terraform: `brew install terraform`
   - terminal-notifier: `brew install terminal-notifier`
   - AWS CLI: `brew install awscli`
   - jq: `brew install jq`
   - yq: `brew install yq`
   - uv: `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh | sh`
   - pipx: `brew install pipx && pipx ensurepath`

3) **Configure AWS profiles:**
   - Check if profile exists: `cat ~/.aws/config | grep aws-sandbox-field-eng_databricks-sandbox-admin`
   - If not found, download config: `curl "https://aws-config.sec.databricks.us/full-config" --output ~/.aws/config`
   - If still having issues, direct user to: https://databricks.atlassian.net/wiki/spaces/UN/pages/2889777163/Use+AWS+CLI+with+Okta+AWS+Identity+Center#Configuration

4) **Configure Atlassian CLI authentication:**
   - Check if ATLASSIAN_API_KEY is set: `echo $ATLASSIAN_API_KEY`
   - If set, attempt login:
     ```bash
     acli jira auth login \
       --site=https://databricks.atlassian.net/ \
       --email=$USER@databricks.com \
       --token <<< $ATLASSIAN_API_KEY
     ```
   - If login succeeds, authentication is complete
   - If ATLASSIAN_API_KEY is not set or login fails:
     a. Direct user to create an API token:
        - Go to: https://id.atlassian.com/manage-profile/security
        - Click on "API tokens"
        - Click "Create and manage API tokens"
        - Create a new token with a descriptive name (e.g., "Claude Code acli")
        - Copy the generated token
     b. Provide the user with this one-liner to add to their ~/.zshrc:
        ```bash
        echo 'export ATLASSIAN_API_KEY="<PASTE_YOUR_TOKEN_HERE>"' >> ~/.zshrc
        ```
     c. Ask the user to:
        - Open a new terminal tab/window
        - Paste the one-liner with their actual token
        - Let you know when they're done
     d. Once user confirms, reload the shell configuration:
        ```bash
        source ~/.zshrc
        ```
     e. Retry the login command to validate:
        ```bash
        acli jira auth login \
       --site=https://databricks.atlassian.net/ \
       --email=$USER@databricks.com \
       --token <<< $ATLASSIAN_API_KEY
        ```
     f. If successful, confirm authentication is complete

5) **Setup directories:**
   - Ensure `~/.vibe` exists
   - Ensure `~/code` exists
   - Download Terraform provider docs from https://github.com/databricks/terraform-provider-databricks/tree/main/docs to `~/.vibe/docs/terraform`

6) **Install gcloud CLI:**
   - Follow instructions at: https://docs.cloud.google.com/sdk/docs/install-sdk

### Vibe Marketplace and Plugins

7) **Update vibe marketplace, permissions, and MCP servers:**
   - Run: `vibe update`
   - This command downloads the latest vibe release and:
     - Updates the marketplace at `~/.vibe/marketplace`
     - Syncs permissions to `~/.claude/settings.json`
     - Syncs MCP server configurations
     - Updates the vibe CLI itself

8) **If only permissions/MCP sync is needed (no download):**
   - Run: `vibe sync`
   - This syncs from the local marketplace without downloading

9) **Check installation status:**
    - Run: `vibe status`
    - This shows:
      - Marketplace installation status
      - Installed plugins
      - Permission and MCP server counts

10) **Diagnose and fix issues:**
    - Run: `vibe doctor`
    - This checks:
      - Prerequisites (gh, jq, yq, claude, python3)
      - Marketplace installation and registration
      - Settings and permissions
      - Outdated cached plugins (like renamed skills)
      - Python3 availability (required for logfood-querier and other tools)
    - It will automatically fix common issues and provide remediation steps

### User Profile Setup

11) **Check for existing vibe profile:**
    - Check if profile exists: `cat ~/.vibe/profile 2>/dev/null`
    - If profile exists, show a summary (name, accounts, last generated date)
    - If profile does not exist, inform the user:
      > "No vibe profile found. The vibe profile stores your accounts, use cases, team members, and Slack channels. This helps other vibe skills provide personalized context."

12) **Offer to build profile:**
    - Ask the user: "Would you like to build your vibe profile now?"
    - If yes, spawn the `vibe-profile` agent to discover and build the profile
    - The agent will:
      - Discover user identity from git config and environment
      - Query Salesforce for assigned accounts and use cases
      - Find relevant Slack channels (external and internal)
      - Look up team members (AEs, DSAs, specialists)
      - Write the profile to `~/.vibe/profile`
    - If no, inform the user they can build it later by asking Claude to "build my vibe profile"

### Completion

13) **Summarize status:**
    - List what was configured
    - List any issues encountered
    - Remind user to restart Claude Code if permissions or plugins were updated

14) **Provide next steps:**
    - If first-time setup: Restart Claude Code and test with a simple command
    - If update: Verify new features work as expected
    - Provide link to vibe documentation if available


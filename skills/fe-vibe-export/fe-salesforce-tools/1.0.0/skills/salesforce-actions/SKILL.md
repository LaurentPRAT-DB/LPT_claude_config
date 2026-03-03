---
name: salesforce-actions
description: Read and update salesforce, including Use Cases, Accounts, Opportunities, Blockers, Escalation Requests, ASQs/Specialist Requests, Preview Feature Requests. 
---


# Salesforce Actions Skill

Read and update salesforce, including Use Cases, Accounts, Opportunities, Blockers, Escalation Requests, ASQs/Specialist Requests.


## Instructions
**IMPORTANT** Do not use the flag -use-tooling-api on any calls! **IMPORTANT**
**IMPORTANT** Use the cli-executor subagent to execute individual commands and to summarize content if needed **IMPORTANT**
1) Ensure authenticated with salesforce
2) To identify an account association, refer to resources/ACCOUNT_LOOKUP.md
3) For object-specific operations, refer to the appropriate documentation:
   - **Use Cases**: resources/UseCase.md (for weekly UCO updates, use `/uco-updates` skill)
   - **Accounts**: resources/Account.md
   - **Opportunities**: resources/Opportunity.md
   - **Cases/Support Cases**: resources/Case.md
   - **JIRA Issues/Tickets**: resources/JiraIssue.md
   - **Workspaces**: resources/Workspace.md
   - **Blockers**: resources/Blocker.md
   - **Aha Ideas**: resources/ahaapp__AhaIdea.md
   - **Escalation Requests/Support Escalations**: resources/Escalation_Request.md
   - **FP Approvals/ASQ Request/Specialist Requests**: resources/FP_Approval.md
   - **Users**: resources/User.md
   - **Preview Feature Requests**: resources/ApprovalRequest.md
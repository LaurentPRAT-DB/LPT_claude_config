---
name: aws-authentication
description: This skill provides instructions for authenticating with aws using aws cli
---

# AWS Authentication Skill

This skill ensures that you are authenticated correctly into the correct AWS environment using the aws CLI 

### Environment Profiles
Use the below profile names for each respective environment:
- aws-sandbox-field-eng_databricks-sandbox-admin, AWS Sandbox Environment. This is the profile to use when you require AWS resources as part of a Databricks demo or Databricks workspace deployment, or just for spinning up any arbitrary AWS resource

### Authentication Process and Running Commands While Authenticated
Before executing any commands, ensure you are authenticated following these steps:
1) Identify the appropriate environment profile name for the task at hand. If none is specified or can't be inferred, default to `aws-sandbox-field-eng_databricks-sandbox-admin` 
2) Run `aws sts get-caller-identity --profile=<profile>` and validate whether the profile exists and if it is valid. If valid, use the profile in subsequent commands with --profile=<profile>
3) If no authenticated profile for intended use case exists, run `aws sso login --profile=<profile>` and ensure the user logs in with SSO.  
4) If you are unable to login, attempt to run configure-vibe
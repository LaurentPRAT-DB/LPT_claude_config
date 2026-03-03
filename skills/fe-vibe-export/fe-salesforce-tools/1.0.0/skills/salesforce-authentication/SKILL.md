---
name: salesforce-authentication
description: This skill provides instructions for authenticating with salesforce before using sf cli or any salesforce work.
---


# Salesforce Authentication Skill

This skill ensures that you are authenticated correctly into Salesforce 


## Instructions
1) Run `sf org display | grep "Connected Status"` and check to see if `Connected`. If so, we are authenticated already. 
2) If not authenticated, run `sf org login web --instance-url=https://databricks.my.salesforce.com/` and ensure the user does SSO flow. 
3) If the sf command is failing, run the `configure-vibe` skill to ensure the environment is setup correctly. 
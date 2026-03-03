# Security Questionnaire (SQRC) Skill

A comprehensive skill for completing security questionnaires and compliance documentation for customer procurement processes using Databricks internal resources.

## Table of Contents

- [Overview](#overview)
- [How to Invoke](#how-to-invoke)
- [Critical Policies](#critical-policies)
- [Complete Workflow](#complete-workflow)
- [Triage Flowchart](#triage-flowchart)
- [Question Categories](#question-categories)
- [Research Workflow](#research-workflow)
- [Validation Workflow](#validation-workflow)
- [Resources](#resources)
- [Related Agents](#related-agents)

---

## Overview

The Security Questionnaire skill guides you through completing customer security questionnaires by:

1. **Triaging** the request to determine the appropriate handling path
2. **Avoiding** custom questionnaires when pre-built content suffices
3. **Researching** answers using the SQRC database (primary source)
4. **Drafting** responses with proper evidence and scoring
5. **Validating** responses before sharing with customers

### Key Features

- Enforces critical policy guardrails (Azure prohibition, no GenAI)
- Targets 90-95% completion using pre-approved SQRC answers
- Distinguishes Databricks-owned vs CSP-inherited controls
- Includes post-completion validation agent

---

## How to Invoke

### Direct Invocation

```
/security-questionnaire
```

### Example Prompts

```
"I need to complete a security questionnaire for a customer"

"Help me answer questions about our SOC 2 and security certifications"

"Customer sent a compliance assessment, can you help fill it out?"
```

### Prerequisites

Before using this skill, ensure you have access to:

| Tool | Purpose |
|------|---------|
| Glean MCP | Search SQRC database and internal docs |
| Slack MCP | Escalation and expert consultation |
| Google Docs skill | Read/create questionnaire documents |

---

## Critical Policies

| Policy | Action | Consequence |
|--------|--------|-------------|
| Azure Databricks | **HARD STOP** - Route to Azure team | Liability risk if violated |
| GenAI Answers | **PROHIBITED** - Use SQRC search only | Frequently contain inaccuracies |
| Custom Answers | **AVOID** - Use pre-built content | Not reviewed by security/legal |
| SQRC First | **REQUIRED** - 90-95% from SQRC | Expert-reviewed answers |

---

## Complete Workflow

![Complete Workflow](diagrams/complete-workflow.svg)

### Workflow Phases

| Phase | Steps | Purpose |
|-------|-------|---------|
| **Initial Checks** | 1-2 | Verify not Azure, check NDA |
| **Avoidance** | 3 | Try pre-built content first |
| **Triage** | 4 | Route appropriately (ESG, Privacy, deal size) |
| **Completion** | 5-8 | Categorize, research, draft, verify controls |
| **Validation** | 9-11 | Validate, review if needed, deliver |

---

## Triage Flowchart

![Triage Decision Tree](diagrams/triage-flowchart.svg)

### Quick Routing Reference

| Condition | Route To |
|-----------|----------|
| Azure Databricks | **HARD STOP** - go/sqrc/azure |
| ESG questions | #esg Slack channel |
| Privacy questions | #privacy Slack channel |
| Deal >= $250K | go/sqrc/submitform |
| Deal < $250K | Self-service with this skill |

---

## Question Categories

![9 Security Question Categories](diagrams/question-categories.svg)

### Category Details

See `resources/CATEGORY_GUIDANCE.md` for detailed guidance on answering questions in each category.

---

## Research Workflow

![Research Priority Order](diagrams/research-workflow.svg)

### Glean Search Examples

```bash
# Search SQRC for training questions
mcp-cli call glean/glean_read_api_call '{"endpoint": "search.query", "params": {"query": "SQRC security training awareness", "page_size": 15}}'

# Search SQRC for penetration testing
mcp-cli call glean/glean_read_api_call '{"endpoint": "search.query", "params": {"query": "SQRC penetration test vulnerability", "page_size": 15}}'

# Search for supporting evidence
mcp-cli call glean/glean_read_api_call '{"endpoint": "search.query", "params": {"query": "Databricks SOC 2 Type II report", "page_size": 15}}'
```

---

## Validation Workflow

![SQRC Validator - 7 Validation Checks](diagrams/validation-workflow.svg)

### Validation Decision Matrix

| Condition | Result |
|-----------|--------|
| Azure detected | **ESCALATE** - Cannot share |
| GenAI suspected | **NEEDS REVIEW** |
| >5 custom answers | **NEEDS REVIEW** |
| <90% completion | **NEEDS REVIEW** |
| Control misattribution | **NEEDS REVIEW** |
| NDA content + unverified NDA | **NEEDS REVIEW** |
| All checks pass | **READY TO SHARE** |

---

## Control Ownership

![Databricks vs CSP Control Ownership](diagrams/control-ownership.svg)

### How to Frame Responses

1. **Lead with Databricks-owned controls** - These are what we directly manage
2. **Reference CSP controls as "inherited"** - Note the cloud provider handles these
3. **Validate through compliance reviews** - Databricks validates CSP controls through compliance report reviews

---

## Resources

### Skill Resources (in `resources/` directory)

| File | Description |
|------|-------------|
| `TRIAGE_FLOWCHART.md` | Decision tree for routing questionnaires |
| `CATEGORY_GUIDANCE.md` | Detailed guidance for each question category |
| `SCORING_GUIDE.md` | Maturity scoring criteria (1-5 scale) |
| `EVIDENCE_SOURCES.md` | Pre-built Glean queries by category |
| `RESPONSE_TEMPLATE.md` | Standard response format template |

### Internal Resources

| Resource | Link | Description |
|----------|------|-------------|
| SQRC Database | go/sqrc | 500+ pre-answered questions |
| Submit for Review | go/sqrc/submitform | Complex questionnaire submission |
| Security Package | go/scpackage | Pre-built security documentation |
| SIG Questionnaire | go/sig | 700+ pre-filled answers |
| Trust FAQ | go/trustfaq | Security and compliance FAQ |

### Public Resources

| Resource | URL |
|----------|-----|
| Trust Center | https://databricks.com/trust |
| Compliance | https://databricks.com/trust/compliance |
| Security Features | https://databricks.com/trust/security-features |
| Privacy Notice | https://databricks.com/legal/privacynotice |
| Security Addendum | https://databricks.com/legal/security-addendum |
| Subprocessors | https://databricks.com/legal/databricks-subprocessors |

---

## Related Agents

### sqrc-questionnaire Agent

For complex questionnaires with 20+ questions, use the `sqrc-questionnaire` agent:

```
Use when:
- Questionnaire has 20+ questions
- Complex compliance assessment
- Need parallel research across categories
```

The agent will:
1. Verify NOT Azure (HARD STOP check)
2. Parse and categorize all questions
3. Research using SQRC as primary source
4. Draft responses with evidence
5. Target 90-95% completion
6. Flag items for escalation

### sqrc-validator Agent

Always run validation before sharing with customers:

```
Use when:
- After completing questionnaire drafting
- Before submitting for security review
- Before delivering to customer
```

The agent validates:
1. Azure check (blocking)
2. GenAI content detection
3. Source verification
4. Custom answer flagging
5. Completeness check (90-95%)
6. Control ownership verification
7. NDA content check

---

## Quick Reference

### Do's

- **DO** check go/sqrc first for every question
- **DO** copy-paste SQRC answers directly
- **DO** verify NDA status before sharing sensitive docs
- **DO** run sqrc-validator before delivering
- **DO** target 90-95% completion from SQRC

### Don'ts

- **DON'T** fill Azure Databricks questionnaires (contractual prohibition)
- **DON'T** use Glean Chat, Perplexity, or ChatGPT
- **DON'T** paraphrase or rewrite SQRC answers
- **DON'T** write custom answers without escalation
- **DON'T** share NDA content without verified NDA

---

## Escalation Contacts

| Type | Channel | When to Use |
|------|---------|-------------|
| Azure | go/sqrc/azure | ALL Azure questionnaires |
| ESG | #esg | Sustainability, governance |
| Privacy | #privacy | GDPR, data subject rights |
| Security | #security | Urgent requests, clarifications |
| Trust Team | go/sqrc/submitform | Custom attestations, regulatory |

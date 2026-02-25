# Claude Code Configuration

Personal Claude Code configuration files for Laurent Prat.

## Contents

| Directory | Description |
|-----------|-------------|
| `agents/` | Custom agent definitions (git, GSD workflow agents) |
| `commands/` | Custom slash commands (city-news, GSD commands) |
| `hooks/` | Session hooks (GSD status line, update checker) |
| `skills/` | 40+ skills for Databricks, MLflow, Spark, and more |
| `plugins/` | Local plugins (medium-article) |
| `projects/*/memory/` | Persistent memory files |

## Setup on a New Machine

1. **Clone the repository:**
   ```bash
   git clone https://github.com/LaurentPRAT-DB/LPT_claude_config.git ~/.claude
   ```

2. **Create settings from templates:**
   ```bash
   cp ~/.claude/settings.json.template ~/.claude/settings.json
   cp ~/.claude/mcp.json.template ~/.claude/mcp.json
   ```

3. **Edit settings.json** and replace placeholders:
   - `YOUR_WORKSPACE` - Databricks workspace URL prefix
   - `YOUR_DATABRICKS_PAT_TOKEN` - Databricks Personal Access Token
   - `YOUR_CONTEXT7_API_KEY` - Context7 MCP API key

4. **Edit mcp.json** and update paths for your machine.

5. **Install plugins** (they are cached separately):
   ```bash
   claude /install fe-vibe
   ```

## What's Excluded

The `.gitignore` excludes sensitive and transient files:
- `settings.json`, `mcp.json` (contain secrets)
- `*.jsonl` (conversation history)
- `plugins/cache/` (reinstallable)
- Session data, telemetry, debug logs

## Skills Overview

### Databricks
- `databricks-app-python` - Build Databricks Apps (Dash, Streamlit, Flask, FastAPI)
- `databricks-app-apx` - Full-stack apps with APX framework
- `databricks-jobs` - Create and manage Databricks Jobs
- `databricks-dbsql` - SQL warehouse features and AI functions
- `databricks-model-serving` - Deploy models and agents
- `databricks-unity-catalog` - System tables and volumes
- `databricks-vector-search` - Vector search indexes
- `databricks-asset-bundles` - DABs deployment
- `lakebase-autoscale` / `lakebase-provisioned` - Managed PostgreSQL

### MLflow
- `mlflow-evaluation` - Agent evaluation with scorers
- `instrumenting-with-mlflow-tracing` - Add tracing to code
- `retrieving-mlflow-traces` - Query traces via API
- `searching-mlflow-docs` - Search MLflow documentation

### Spark
- `spark-declarative-pipelines` - Lakeflow SDP/LDP pipelines
- `spark-structured-streaming` - Streaming best practices

### Other
- `agent-evaluation` - Evaluate and optimize LLM agents
- `medium-article` - Create Medium articles from GitHub repos
- `synthetic-data-generation` - Generate test data with Faker

## GSD (Get Shit Done) Workflow

The `commands/gsd/` directory contains a complete project management workflow:
- `/gsd:new-project` - Initialize a new project
- `/gsd:plan-phase` - Plan implementation phases
- `/gsd:execute-phase` - Execute plans with atomic commits
- `/gsd:debug` - Systematic debugging with state tracking
- `/gsd:progress` - Check project progress

## License

Private configuration - not for redistribution.

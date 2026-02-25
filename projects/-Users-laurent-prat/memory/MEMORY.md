# Claude Code Memory - Laurent Prat

## User Identity
- **Name**: Laurent Prat
- **Email**: laurent.prat@databricks.com
- **Salesforce User ID**: 0058Y00000C0P5ZQAV

## Salesforce UCO Queries
**IMPORTANT**: To find Laurent's Use Cases, query via `Account.Last_SA_Engaged__c` field, NOT via UseCase owner/SA fields.

See detailed patterns: [salesforce-uco-queries.md](./salesforce-uco-queries.md)

Quick reference:
1. Get accounts: `SELECT Id FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV'`
2. Get UCOs: `SELECT ... FROM UseCase__c WHERE Account__c IN (<account_ids>)`

## UCO Onboarding Documentation
- **U5 UCOs require onboarding docs** - Template: [uco-onboarding-template.md](./uco-onboarding-template.md)
- Docs must be owned by laurent.prat@databricks.com and shared with databricks.com domain as VIEWER

### Key Field Mappings (MEDDPICC Section)
| UI Label | API Field | Clickable? |
|----------|-----------|------------|
| Onboarding Doc (Link) | `Artifact_Link__c` | Yes ✓ |
| Eval Doc (GDrive Link) | `POC_Doc__c` | Yes ✓ |
| Description (Overview) | `Use_Case_Description__c` | No |

### What Works via API
- **`Artifact_Link__c`** - Best! Clickable link in MEDDPICC > Path to Production
- **`Use_Case_Description__c`** - Append link text for copy-paste access

### What Requires Manual UI
- **"Associate Documents" modal** - API cannot populate this section
- See [salesforce-uco-queries.md](./salesforce-uco-queries.md) for debugging lessons learned

## Environment
- Salesforce CLI: `/opt/homebrew/bin/sf` (installed via Homebrew)
- Default org: `laurent.prat@databricks.com`

## Google Workspace Tools

### Google Sheets API
- **Excel files (.xlsx) on Google Drive cannot be accessed via Sheets API** - returns "This operation is not supported for this document"
- **Solution**: User must first save/convert to native Google Sheets format, then share new URL
- Quota project required: `gcp-sandbox-field-eng`

### Gmail API
- Draft creation works via `gmail_builder.py create-draft` with `--html` for rich formatting
- Location: `/Users/laurent.prat/.claude/plugins/cache/fe-vibe/fe-google-tools/1.1.0/skills/gmail/resources/gmail_builder.py`

## Custom Skills

### medium-article-from-git-repo
Create professional Medium articles from GitHub repositories with diagrams.
- **Location:** `~/.claude/skills/medium-article-from-git-repo.md`
- **Reference:** https://github.com/LaurentPRAT-DB/ACME_Workspace_Usage_Dashboard

**File Outputs:**
| File | Purpose |
|------|---------|
| `MEDIUM_ARTICLE.md` | Source markdown (editing/version control) |
| `medium_article_v1.html` | **USE THIS** for Medium import |

**Workflow:** Markdown (source) → HTML (import) → Medium (publish)

**Mermaid Diagrams:**
- Use `<br/>` NOT `\n` for line breaks
- Generate: `mmdc -i file.mmd -o file.png -b white -w 1200`

**Medium Import:**
- Requires **GitHub Pages HTML** (markdown URLs don't work)
- Import: `https://OWNER.github.io/REPO/medium_article_v1.html`

**Gist Marker Pattern:**
```html
<p class="gist-marker">GIST #1<br>https://gist.github.com/USER/ID</p>
```
- After import: search `GIST #`, delete marker, paste URL on empty line

**⚠️ Mobile Limitation:** Gists don't render reliably on Medium iOS/Android apps (Embedly/JS issue). Workarounds:
- Add fallback link with `/raw`: `📱 On mobile? [View raw code](gist-url/raw)`
- Use Medium native code blocks for short/critical snippets
- Always test on mobile after publishing

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done (Goal-Driven Execution)
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a senior engineer say this is overcomplicated?"
- Run tests, check logs, demonstrate correctness

**Transform tasks into success criteria BEFORE coding:**
- "Fix bug" → Write reproducing test → verify fails → fix → verify passes
- "Add feature" → Define acceptance criteria → implement → verify each criterion
- "Refactor X" → Ensure tests pass before AND after

**Multi-step plan format** (embed verification per step):
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Don't proceed past a step until its verify check passes.

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

### 7. Git Discipline
- Commit early, commit often — small atomic commits with clear messages
- Never commit to `main` directly — always use feature branches
- Branch naming: `<type>/<short-description>` (e.g., `fix/auth-timeout`, `feat/export-csv`)
- Don't bundle unrelated changes in one commit — if you can't describe it in one sentence, split it
- When in doubt, ask before pushing — pushes are hard to undo
- **Merge to main workflow** (solo): `git checkout main && git merge <branch> && git push origin main`
- Never force-push to `main` — if main is ahead, rebase your branch onto main first

### 8. Testing Strategy
- If modifying existing code: run existing tests first, fix what breaks
- If adding new logic with clear inputs/outputs: write a test
- Don't write tests for glue code, config, or trivial wiring
- Test behavior, not implementation — tests should survive refactors
- A failing test is a better bug report than a paragraph of description

### 9. Communication Style
- Lead with the action or answer, not the reasoning
- Show diffs and results — don't describe what you did in prose
- Flag blockers and decisions immediately — don't bury them
- One message per concern — don't batch unrelated updates
- Silence is fine — don't narrate trivial steps

### 10. Error Recovery
- First failure: investigate root cause, don't retry blindly
- Three consecutive failures on same approach: stop, re-assess, propose alternatives
- Never suppress or work around errors without explaining why
- If the environment is broken (deps, auth, permissions): say so immediately, don't waste cycles

### 11. Assumption Surfacing
- For **customer-facing work** (Salesforce mutations, UCO updates, emails, external docs): list assumptions explicitly before executing. Wrong assumptions here cost rework or damage relationships.
- For **data mutations** (SOQL updates, sheet writes, API calls that change state): state what you're about to change and what you expect the current state to be.
- For **pure coding tasks** in auto-mode: make reasonable calls silently as usual — this rule does NOT slow down code work.
- If multiple interpretations exist for a customer request, present them — don't pick silently.

## Knowledge Lifecycle (Memory Extensions)

Memory files use extended frontmatter with **confidence** and **domain** fields:

```markdown
---
name: {{memory name}}
description: {{one-line description}}
type: {{user, feedback, project, reference}}
confidence: {{confirmed | hypothesis}}
confirmations: {{number, starting at 1}}
domain: {{domain tag, e.g. salesforce, onboarding, pricing, tooling, google-workspace}}
---
```

### Confidence Levels
- **hypothesis** — Observed pattern, needs more data. Apply cautiously, note it's unconfirmed.
- **confirmed** — Validated 3+ times. Apply by default.

### Lifecycle Rules
1. **New insight** → save as `hypothesis` with `confirmations: 1`
2. **Same pattern observed again** → increment `confirmations`
3. **confirmations >= 3** → promote `confidence` to `confirmed`
4. **Contradicted by new data** → demote back to `hypothesis`, reset `confirmations: 1`, add note about the contradiction
5. **Before starting a task** → review confirmed memories for the relevant domain. Check if any hypothesis can be tested with today's work.
6. **After completing a task** → extract insights, save new memories or update existing ones.

### Domain Tags
Use consistent tags across memories. Current domains:
- `salesforce` — UCO queries, field mappings, SFDC patterns
- `onboarding` — UCO onboarding docs, templates
- `tooling` — Installation, CLI tools, environment setup
- `google-workspace` — Sheets, Gmail, Drive, Docs APIs
- `skills` — Custom skill patterns and lessons
- `writing` — Medium articles, documentation patterns

Add new domains as needed. Keep the MEMORY.md index grouped by domain when it makes sense.

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

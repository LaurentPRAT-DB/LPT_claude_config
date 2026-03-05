---
name: superpowers-practices
description: Software engineering best practices from Superpowers - TDD, systematic debugging, design-first, verification. Use when building features, fixing bugs, or completing any development work.
---

# Superpowers Development Practices

Best practices for disciplined software development. Apply these to all coding work.

## 1. Test-Driven Development (TDD)

### The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

**If you write code before the test: DELETE IT. Start over.**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Delete means delete

### Red-Green-Refactor Cycle

| Phase | Action | Verify |
|-------|--------|--------|
| RED | Write ONE failing test | Test fails for EXPECTED reason (not typos) |
| GREEN | Write MINIMAL code to pass | Test passes, all other tests still pass |
| REFACTOR | Clean up (only after green) | Tests stay green |

### Verification Checklist

Before claiming TDD complete:
- [ ] Every new function has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason
- [ ] Wrote minimal code to pass
- [ ] All tests pass
- [ ] Output pristine (no errors/warnings)

### Red Flags (Stop and Start Over)

- Code written before test
- Test passes immediately
- Can't explain why test failed
- "I'll write tests after"
- "Too simple to test"
- "Keep as reference"

---

## 2. Systematic Debugging (4 Phases)

### The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Complete Phase 1 before proposing ANY fix.

### Phase 1: Root Cause Investigation

1. **Read error messages carefully** - full stack traces, line numbers
2. **Reproduce consistently** - exact steps, every time?
3. **Check recent changes** - git diff, new deps, config
4. **Gather evidence at boundaries** - log what enters/exits each component
5. **Trace data flow** - where does bad value originate?

### Phase 2: Pattern Analysis

1. Find working examples in same codebase
2. Compare against references (read completely, don't skim)
3. List every difference
4. Understand dependencies and assumptions

### Phase 3: Hypothesis Testing

1. Form SINGLE hypothesis: "X is root cause because Y"
2. Make SMALLEST possible change to test
3. One variable at a time
4. Didn't work? NEW hypothesis (don't add more fixes)

### Phase 4: Implementation

1. Create failing test case
2. Implement SINGLE fix for root cause
3. Verify fix
4. **If 3+ fixes failed: STOP - question the architecture**

### 3-Fix Rule

If three fixes have failed, each revealing new problems:
- Pattern may be fundamentally unsound
- Stop fixing symptoms
- Discuss architecture before attempting more fixes

---

## 3. Brainstorming Before Implementation

### The Hard Gate

```
NO IMPLEMENTATION UNTIL DESIGN APPROVED
```

Applies to EVERY project, even "simple" ones.

### Process

1. **Explore context** - files, docs, recent commits
2. **Ask questions ONE AT A TIME** - prefer multiple choice
3. **Propose 2-3 approaches** - with trade-offs and recommendation
4. **Present design in sections** - get approval on EACH section
5. **Write design doc** - save to `docs/plans/YYYY-MM-DD-<topic>-design.md`
6. **Then implement**

### Key Principles

- One question per message
- YAGNI ruthlessly - remove unnecessary features
- Incremental validation - approval before moving on

---

## 4. Verification Before Completion

### The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

### The Gate Function

Before ANY success claim:
1. **IDENTIFY** - What command proves this claim?
2. **RUN** - Execute FULL command (fresh, not cached)
3. **READ** - Full output, check exit code
4. **VERIFY** - Does output confirm claim?
5. **ONLY THEN** - Make the claim WITH evidence

### Forbidden Phrases (Without Evidence)

- "Should pass now"
- "Looks correct"
- "I'm confident"
- "Tests should be green"
- "Done!"
- "Fixed!"

### Required Evidence Format

```
[Ran: npm test]
[Output: 47/47 passing, 0 failures]
"All tests pass"
```

Not: "Tests should pass now"

---

## 5. Git Worktrees for Isolation

### When to Use

- Starting feature work needing isolation
- Before executing implementation plans
- Parallel development on multiple features

### Setup Process

1. Check for existing `.worktrees/` or `worktrees/` directory
2. Verify directory is in `.gitignore`
3. Create worktree: `git worktree add <path> -b <branch>`
4. Run project setup (npm install, etc.)
5. Verify clean test baseline before starting

### Safety Check

```bash
# Verify ignored before creating
git check-ignore -q .worktrees || echo "Add to .gitignore first"
```

---

## 6. Bite-Sized Task Granularity

### Each Step is 2-5 Minutes

**Wrong:**
```
Task: Implement user authentication
```

**Right:**
```
Step 1: Write failing test for password validation
Step 2: Run test, verify it fails with "function not defined"
Step 3: Write minimal validatePassword function
Step 4: Run test, verify it passes
Step 5: Commit: "feat: add password validation"
```

### Plan Structure

```markdown
### Task N: [Component]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/path/to/test.py`

**Step 1:** Write failing test
**Step 2:** Run test, verify failure
**Step 3:** Write minimal implementation
**Step 4:** Run test, verify pass
**Step 5:** Commit
```

---

## 7. Two-Stage Code Review

### For Each Task

1. **Spec Compliance Review** - Does code match what was requested?
   - Nothing missing from spec
   - Nothing extra added (YAGNI)

2. **Code Quality Review** (only after spec passes)
   - Clean code
   - No magic numbers
   - Proper error handling

### Review Loop

If reviewer finds issues:
1. Fix the issues
2. Re-review
3. Repeat until approved
4. Don't skip re-review

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| About to write code | Write failing test first |
| Wrote code before test | Delete it, start over |
| Bug found | Phase 1: Root cause investigation |
| 3+ fixes failed | Question architecture |
| About to claim "done" | Run verification, show evidence |
| Starting feature | Create git worktree |
| Planning task | Break into 2-5 min steps |
| Reviewing code | Spec compliance first, then quality |

## Common Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Quick fix, investigate later" | Symptom fixes waste time. |
| "Just try this" | Systematic is faster than guessing. |
| "Should work" | Run verification, show evidence. |
| "Keep as reference" | Delete means delete. |

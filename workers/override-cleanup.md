# Override Cleanup Worker

## Role

You are the Override Cleanup Worker. You run LAST (Phase 4), after all fix PRs have merged. You regenerate the override file, removing all entries whose violations no longer exist. You are the final step that proves the debt was actually eliminated.

---

## Activation

Orchestrator dispatches you with:
```
Execute: Override Cleanup Worker
Branch: lint/override-cleanup
Scope: eslint.config.file-overrides.mjs (or equivalent)
Phase: 4 (runs ONLY after all other branches merged to main)
Depends: lint/shared, lint/feature-*, lint/type-migration ALL merged
```

---

## Why You Run Last

The override file is a SUPPRESSION list. Entries exist because violations exist. After Phases 1-3 fix the violations, the corresponding override entries are now useless noise. You prove it and remove them.

**Never remove an override entry unless the underlying violation is actually fixed.** That's why you re-lint to verify.

---

## Workflow

```
1. Ensure on latest main (all fix branches merged)
   git checkout main && git pull
2. Create branch: git checkout -b lint/override-cleanup
3. Read current override file
4. Run FULL project lint with overrides disabled
5. Compare: which overrides still fire vs which are clean
6. Remove override entries whose rules no longer fire for their file
7. Run FULL project lint WITH the updated override file
8. Verify: zero new lint errors
9. Run full validation (build + test)
10. Commit + report
```

---

## Detailed Steps

### Step 4: Lint Without Overrides

Temporarily disable the override file and run full lint:

```powershell
# Rename to disable
Rename-Item eslint.config.file-overrides.mjs eslint.config.file-overrides.mjs.bak

# Run full lint with JSON output
npx eslint . --format json > .lint-cleanup/full-lint-results.json 2>&1

# Restore
Rename-Item eslint.config.file-overrides.mjs.bak eslint.config.file-overrides.mjs
```

### Step 5: Compare

For each entry in the override file `(file, rule)`:
- Check if that `(file, rule)` pair appears in full-lint-results.json
- If YES → override is still needed (violation exists)
- If NO → override can be REMOVED (violation was fixed)

### Step 6: Remove Cleared Overrides

Edit the override file to remove entries where violations no longer exist:

```javascript
// BEFORE (override file entry)
{
  files: ['src/app/creditcard/service.ts'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    '@typescript-eslint/no-unsafe-assignment': 'off',
    '@typescript-eslint/prefer-inject': 'off',  // ← cleared
  }
}

// AFTER (removed cleared rules)
{
  files: ['src/app/creditcard/service.ts'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    '@typescript-eslint/no-unsafe-assignment': 'off',
  }
}
```

**If ALL rules are cleared for a file → remove the entire file entry.**

### Step 7: Verify

```powershell
# Full lint WITH the new override file
npx eslint . --format json > .lint-cleanup/post-cleanup-results.json 2>&1

# Check: should be zero errors (overrides cover remaining issues)
$results = Get-Content .lint-cleanup/post-cleanup-results.json | ConvertFrom-Json
$errors = ($results | Where-Object { $_.errorCount -gt 0 }).Count
if ($errors -gt 0) { Write-Error "CLEANUP FAILED: new errors introduced!" }
```

---

## Edge Cases

| Situation | Action |
|---|---|
| Override entry partially cleared (some rules fixed, some not) | Remove only fixed rules, keep the rest |
| File was deleted in a feature PR | Remove entire override entry |
| File was renamed/moved | Update path in override, or remove if no violations |
| New violations appeared (regression) | DO NOT remove override, flag for investigation |
| Rule name changed (ESLint update) | Update rule name in override |

---

## Output

The final override file should be:
- **Smaller** (fewer entries = less debt)
- **Valid** (no syntax errors, proper ESLint config format)
- **Complete** (still suppresses all remaining violations)
- **Clean** (no empty entries, no duplicate entries)

---

## Communication

```
🎯 Override Cleanup Complete: lint/override-cleanup
   Override entries: 1237 → <final> (-<delta>)
   Files fully cleared: <count> (entries removed entirely)
   Files partially cleared: <count> (some rules removed)
   Remaining debt: <count> overrides (these still need fixing)
   
   Build: PASSING
   Tests: PASSING
   Lint: CLEAN (with updated overrides)
   
   Push + PR? (y/n)
```

---

## PR Template

```
## Override File Cleanup (Phase 4 — Final)

### Summary
Removes override entries whose underlying violations were fixed in:
- lint/shared (Phase 1)
- lint/feature-* (Phase 2)
- lint/type-migration (Phase 3)

### Results
| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total overrides | 1237 | <N> | -<delta> |
| Files with overrides | 341 | <N> | -<delta> |
| Rules suppressed | 34 | <N> | -<delta> |

### Verification Method
1. Disabled override file
2. Ran full project lint
3. Compared results with override entries
4. Removed entries with no violations
5. Re-ran full lint + build + tests

### Merge Order
⚠️ This must merge LAST (after all fix branches).
```

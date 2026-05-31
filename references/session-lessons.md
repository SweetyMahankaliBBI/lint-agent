# Session Lessons — Learned the Hard Way

## File Editing Rules

### NEVER use PowerShell regex for file edits
- `$content -replace` with backtick-n inserts literal `\`n` characters, not newlines
- **Always use `replace_string_in_file` or `multi_replace_string_in_file`** tools
- Terminal is for READ-ONLY operations only (grep, search, check)

### NEVER prepend imports without checking existing ones
- Before adding `import { X } from 'module'`, search if `module` is already imported
- If it is, merge into the existing import statement
- Duplicate imports cause `no-duplicate-imports` errors (build-breaking)

### NEVER use `as never` — use `as unknown as T`
- Per project coding standards

---

## Type Migration (`any` → proper types)

### Check ALL call sites before changing a method signature
- When `any` is removed, the method may have been accepting extra arguments silently
- Example: `endEvent(false)` was actually `endEvent(false, errorMessage)` — the `any` type hid the 2nd arg
- **Before fixing a method's types, grep for all usages and verify the actual contract**

### Mock typing strategy for tests
- Cast at the **usage site**, not the variable declaration:
  ```typescript
  // ✅ GOOD — spy access still works
  const mock = { endEvent: jasmine.createSpy() };
  service.method.and.returnValue(mock as unknown as FormTimedEvent);
  expect(mock.endEvent).toHaveBeenCalledWith(false, 'msg'); // works!

  // ❌ BAD — spy access broken
  const mock = { endEvent: jasmine.createSpy() } as unknown as FormTimedEvent;
  expect(mock.endEvent).toHaveBeenCalledWith(false, 'msg'); // TS error!
  ```

### Common `any` replacement patterns
| Original | Replacement |
|----------|-------------|
| `(obj: any): any => obj` | `(obj: unknown): unknown => obj` |
| `(): any => {}` | `(): void => {}` (if no return needed) |
| `(component as any).prop` | `(component as unknown as { prop: Type }).prop` |
| `{} as ICellRendererParams` | `{} as unknown as ICellRendererParams` |
| `mockEvent as FormTimedEvent` | Cast at `.returnValue()` not declaration |

---

## Validation Strategy

### Validate every 5 files (not at the end)
- Run `tsc + eslint` after each batch of ~5 files
- Catches cascading errors early before they multiply
- Saves 30+ minutes vs. fixing 50 errors at once

### Run tests BEFORE committing
```powershell
npx tsc --noEmit 2>&1 | Select-String "error" | Measure-Object
npx eslint "src/app/settings/" 2>&1 | Select-String "problems"
npx ng test --watch=false --browsers=ChromeHeadless 2>&1 | Select-String "TOTAL"
```

### Check method name casing carefully
- `logFormClosed` vs `logFormclosed` — one capital letter broke 6 tests
- After any rename/retype, verify the exact casing matches

---

## Git Operations

### Always check `git status` before amend
- If in a merge state, `git commit --amend` fails
- Use `git commit` to complete the merge first

### Never leave conflict markers
- After resolving conflicts, always run `npx tsc --noEmit` to catch `TS1185: Merge conflict marker encountered`

---

## Performance Tips

### Limit terminal output
- Use `| Measure-Object` for counts instead of printing all errors
- Use `| Select-Object -First 20` to avoid massive output
- Use `| Select-String "pattern"` to filter to relevant lines

### Batch fixes by pattern
- Fix all instances of the same pattern across files simultaneously using `multi_replace_string_in_file`
- Don't fix one file at a time when 10 files need the same change

### Don't re-run tsc for the full project repeatedly
- After initial full check, scope to changed files: `npx tsc --noEmit 2>&1 | Select-String "settings"`
- Full tsc takes 30-60 seconds each time

---

## Angular-Specific

### FormTimedEvent vs ButtonTimedEvent
- `FormTimedEvent.endEvent(success: boolean, errorMessage?: string)` — 2 args
- `ButtonTimedEvent.endEvent(success: boolean)` — 1 arg only
- When type is union `ButtonTimedEvent | FormTimedEvent`, cast to `FormTimedEvent` at the specific call site if you need the 2nd arg

### AbstractControl → UntypedFormArray
- `.controls` property only exists on `FormArray`/`FormGroup`, not `AbstractControl`
- Cast: `(form.controls.field as UntypedFormArray).controls.length`

### ICellRendererParams for ag-grid
- `agInit({})` → `agInit({} as unknown as ICellRendererParams)`
- Import from `'ag-grid-community'`

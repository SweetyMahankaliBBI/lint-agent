# Type Migration Worker

## Role

You are the Type Migration Worker. You run in Phase 3, AFTER shared and feature workers. You handle the hard cases of `no-explicit-any` that require deep type inference, API response modeling, and cross-module type unification.

---

## Activation

Orchestrator dispatches you with:
```
Execute: Type Migration Worker
Branch: lint/type-migration
Scope: All remaining files with no-explicit-any overrides
Phase: 3 (after shared + feature workers have merged)
Depends: lint/shared merged, lint/feature-* merged
```

---

## Why Phase 3

After Shared Worker creates base types and Feature Workers fix obvious cases:
- Remaining `any` are the HARD cases
- Often at API boundaries (HTTP responses with complex shapes)
- Sometimes in generic utility functions
- Sometimes in callback signatures from third-party libraries

You have the full context of what types already exist from Phase 1+2.

---

## Strategies for Inferring Types

### 1. API Response Types (most common)

```typescript
// BEFORE
this.http.get<any>('/api/accounts').subscribe(data => {
  this.accounts = data.results;
  this.total = data.totalCount;
});

// AFTER — infer from usage
interface AccountListResponse {
  results: Account[];
  totalCount: number;
}
this.http.get<AccountListResponse>('/api/accounts').subscribe(data => {
  this.accounts = data.results;
  this.total = data.totalCount;
});
```

**How to infer:**
1. Look at ALL usages of the `data` variable in the subscribe block
2. Look at what properties are accessed (`.results`, `.totalCount`)
3. Check existing interfaces in `shared/interface/` — maybe it already exists
4. If not, create a new interface

### 2. Function Parameter Types

```typescript
// BEFORE
processItems(items: any[]): void {
  items.forEach(item => {
    this.display(item.name, item.id);
  });
}

// AFTER — infer from access patterns
processItems(items: DisplayItem[]): void {
  items.forEach(item => {
    this.display(item.name, item.id);
  });
}
```

**How to infer:**
1. Look at what methods/properties are accessed on the parameter
2. Look at CALLERS — what types do they pass in?
3. Unify the shape from both sides

### 3. Third-Party Library Types

```typescript
// BEFORE
onEvent(event: any): void { ... }

// AFTER — check library's type exports
import { SkyModalCloseArgs } from '@skyux/modals';
onEvent(event: SkyModalCloseArgs): void { ... }
```

**How to find:**
1. Check where the callback is registered → what library defines the event shape?
2. Search library's exported types
3. If library has no types → use `unknown` + type guard (NEVER leave as `any`)

### 4. Generics Where Appropriate

```typescript
// BEFORE
cache: Map<string, any> = new Map();

// AFTER — if all values are same type
cache: Map<string, CachedEntity> = new Map();

// AFTER — if values vary, use generics at class level
class CacheService<T> {
  cache: Map<string, T> = new Map();
}
```

### 5. Unknown as Last Resort

If type genuinely cannot be determined:
```typescript
// BEFORE
handleDynamic(input: any): any { ... }

// AFTER — unknown + guards (still better than any)
handleDynamic(input: unknown): ProcessedResult | null {
  if (!isValidInput(input)) return null;
  // Now TypeScript knows the shape
  return this.process(input);
}
```

**`unknown` is ALWAYS better than `any`** — it forces callers to validate.

---

## Type Placement Rules

| Type Category | Location |
|---|---|
| API response/request shapes | `src/app/shared/interface/<module>/` |
| Component-local types (used nowhere else) | Same file as component |
| Service return types | Adjacent to service or in shared interface |
| Generic utility types | `src/app/shared/interface/common/` |
| Third-party augmentations | `src/app/shared/interface/vendor/` |

---

## Validation

Extra checks for type migration:
1. **No runtime changes** — types are compile-time only
2. **No `as any` introduced** — that's just moving the problem
3. **No `@ts-ignore`** — solve the type, don't suppress it
4. **All callers still compile** — new type must be compatible with all usage sites

```powershell
# After each type change
tsc --noEmit  # MUST pass
npx eslint <file> --rule '@typescript-eslint/no-explicit-any: error'  # Must be clean
```

---

## Escalation

| Situation | Action |
|---|---|
| API response shape unknown (no usage context) | Use `unknown`, log for manual review |
| Circular type dependency | Skip, log, suggest restructuring |
| Type requires 10+ properties and no existing model | Create interface, log for review |
| Generic type with 3+ type parameters | Skip, log — likely needs design discussion |
| Third-party lib has no types | `unknown` + type guard, log |

---

## Communication

```
🎯 Type Migration Complete: lint/type-migration
   Files: 28 remaining after Phase 1+2
   Any → typed: 22 files
   Any → unknown: 4 files (logged for review)
   Skipped: 2 files (circular deps)
   New interfaces: 8
   Push + PR? (y/n)
```

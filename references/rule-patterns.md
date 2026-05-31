# Fix Recipes — Per-Rule Patterns

## Overview

This file contains the exact fix pattern for each lint rule the agent will encounter. Workers reference this during the manual fix loop to apply correct, consistent transformations.

---

## P1 — Quick Wins (Low Risk, Autofix-Friendly)

### `@typescript-eslint/no-unused-vars`

**What:** Variable/import declared but never used.

```typescript
// ❌ Before
import { Component, Input, OnInit } from '@angular/core'; // Input unused
const result = getValue(); // result never used

// ✅ After
import { Component, OnInit } from '@angular/core';
getValue(); // if side-effect needed, or remove entirely
```

**Heuristics:**
- If unused import → remove from import list
- If unused variable assigned from function → check if function has side effects
  - Side effects → keep call, remove assignment: `getValue();`
  - No side effects → remove entire line
- If unused function parameter → prefix with `_`: `(_event: Event)`

---

### `@typescript-eslint/prefer-const`

**What:** Variable declared with `let` but never reassigned.

```typescript
// ❌ Before
let name = user.getName();
let items = [1, 2, 3];

// ✅ After
const name = user.getName();
const items = [1, 2, 3];
```

**Autofix:** `eslint --fix` handles this. Safe.

---

### `@angular-eslint/id-denylist`

**What:** Identifier uses a restricted name (e.g., `number`, `string`, `boolean`).

```typescript
// ❌ Before
const account = { id: 1, number: '100' };

// ✅ After — quote the property name in object type/literal
const account = { id: 1, 'number': '100' };

// Or rename if it's a variable
const accountNumber = '100'; // preferred if feasible
```

**Note:** In spec files, quoting is the fix. In production code, consider renaming.

---

### `@typescript-eslint/explicit-member-accessibility`

**What:** Class member missing `public`/`private`/`protected` modifier.

```typescript
// ❌ Before
class MyComponent {
  data: string;
  ngOnInit() { ... }
}

// ✅ After
class MyComponent {
  public data: string;
  public ngOnInit(): void { ... }
}
```

**Pattern:**
- Angular lifecycle methods → `public`
- Template-bound properties → `public`
- Internal state → `private` with `_` prefix
- Injected services → `private readonly`

---

## P2 — Pattern Modernization (Medium Risk)

### `@angular-eslint/prefer-inject`

**What:** Using constructor DI instead of `inject()`.

```typescript
// ❌ Before
export class MyComponent {
  constructor(
    private _service: MyService,
    private _router: Router,
    private _cdr: ChangeDetectorRef,
  ) {}
}

// ✅ After
export class MyComponent {
  private readonly _service = inject(MyService);
  private readonly _router = inject(Router);
  private readonly _cdr = inject(ChangeDetectorRef);

  constructor() {} // Remove if empty, or keep if has logic
}
```

**Important:**
- Add `inject` to `@angular/core` import
- Keep `readonly` since injected values never change
- If constructor has logic (not just DI), keep constructor with logic, move DI to fields
- Watch for `@Inject(TOKEN)` → `inject(TOKEN)`
- Watch for `@Optional()` → `inject(Service, { optional: true })`

---

### `@typescript-eslint/prefer-optional-chain`

**What:** Manual null checks instead of `?.`.

```typescript
// ❌ Before
if (obj && obj.prop && obj.prop.value) { ... }
const name = item && item.name ? item.name : '';

// ✅ After
if (obj?.prop?.value) { ... }
const name = item?.name ?? '';
```

**Autofix available but VERIFY:** `?.` returns `undefined` (not `false`/`''`/`0`). If code relied on falsy-specific behavior, the fix changes semantics.

---

### `@typescript-eslint/prefer-nullish-coalescing`

**What:** Using `||` where `??` is more correct.

```typescript
// ❌ Before
const value = input || 'default'; // fails for 0, '', false

// ✅ After
const value = input ?? 'default'; // only null/undefined trigger default
```

**⚠️ CAREFUL:** `??` only checks null/undefined. `||` checks all falsy. If `0`, `''`, or `false` are valid values that should NOT trigger the default → `??` is correct. If they should trigger the default → keep `||`.

---

### `@typescript-eslint/prefer-for-of`

**What:** `for (let i = 0; ...)` where index isn't used (only `arr[i]`).

```typescript
// ❌ Before
for (let i = 0; i < items.length; i++) {
  process(items[i]);
}

// ✅ After
for (const item of items) {
  process(item);
}
```

**Autofix:** Usually safe. Check that loop doesn't use `i` for anything else.

---

## P3 — Type Safety (Higher Risk)

### `@typescript-eslint/no-explicit-any`

**What:** Explicit `any` type annotation.

```typescript
// ❌ Before
function process(data: any): any { ... }
let cache: Map<string, any>;

// ✅ After — INFER from usage
function process(data: AccountRecord): ProcessResult { ... }
let cache: Map<string, CachedEntity>;

// ✅ After — if truly unknowable
function handle(input: unknown): void {
  if (isValidInput(input)) { ... }
}
```

**Strategy:** See `workers/type-migration.md` for detailed inference techniques.

---

### `@typescript-eslint/no-unsafe-assignment`

**What:** Assigning `any`-typed value to a typed variable.

```typescript
// ❌ Before
const data: any = response.body;
this.items = data.results; // unsafe assignment

// ✅ After
const data = response.body as AccountListResponse;
this.items = data.results;

// ✅ Better — type the source
const data: AccountListResponse = response.body;
```

**Fix the SOURCE (the `any`), not the assignment.** Chain up to where `any` enters.

---

### `@typescript-eslint/no-unsafe-member-access`

**What:** Accessing a property on an `any`-typed value.

```typescript
// ❌ Before
const name = data.user.name; // data is any

// ✅ After — type data properly
interface UserResponse { user: { name: string } }
const typedData: UserResponse = data;
const name = typedData.user.name;
```

**Fix:** Type the variable, then member access becomes safe automatically.

---

### `@typescript-eslint/no-unsafe-call`

**What:** Calling an `any`-typed value as a function.

```typescript
// ❌ Before
const handler: any = getHandler();
handler(); // unsafe call

// ✅ After
type Handler = () => void;
const handler: Handler = getHandler();
handler();
```

---

### `@typescript-eslint/no-unsafe-argument`

**What:** Passing an `any`-typed value as an argument.

```typescript
// ❌ Before
processItem(data.item); // data is any → data.item is any

// ✅ After — type data
const typedData: ItemResponse = data;
processItem(typedData.item);
```

---

### `@typescript-eslint/no-unsafe-return`

**What:** Returning an `any`-typed value from a typed function.

```typescript
// ❌ Before
getData(): string {
  return this.cache.get('key'); // cache is Map<string, any>
}

// ✅ After — fix the cache type
private cache: Map<string, string> = new Map();
getData(): string {
  return this.cache.get('key') ?? '';
}
```

---

### `@typescript-eslint/no-unsafe-enum-comparison`

**What:** Comparing enum value with incompatible type.

```typescript
// ❌ Before
if (status === 'approved') { ... } // status is enum, 'approved' is string

// ✅ After
if (status === StatusEnum.Approved) { ... }
```

---

## P4 — Deprecated APIs & Behavioral

### `@typescript-eslint/no-deprecated`

**What:** Using a deprecated API/method/class.

**General approach:**
1. Read the deprecation message (hover in IDE or check JSDoc)
2. It usually says "Use X instead"
3. Replace with the recommended alternative
4. If no alternative documented → skip, log for manual review

**Common Angular deprecations:**
```typescript
// ❌ ComponentFixtureAutoDetect → use fixture.autoDetectChanges()
// ❌ async() test helper → use waitForAsync()
// ❌ TestBed.get() → use TestBed.inject()
// ❌ @ViewChild with static → use { static: true/false } explicitly
```

---

### `@typescript-eslint/no-floating-promises`

**What:** Promise not handled (no await, .then, .catch, or void).

```typescript
// ❌ Before
this.router.navigate(['/home']); // returns Promise

// ✅ After — explicit void
void this.router.navigate(['/home']);

// ✅ After — await (if in async context)
await this.router.navigate(['/home']);

// ✅ After — handle (if error matters)
this.router.navigate(['/home']).catch(err => this.handleNavError(err));
```

**Heuristic:**
- Navigation calls → `void` (we don't care about result)
- Data operations → `await` or `.catch()` (errors matter)
- Fire-and-forget → `void` operator

---

### `@typescript-eslint/no-shadow`

**What:** Variable in inner scope shadows outer scope variable.

```typescript
// ❌ Before
const items = this.allItems;
items.forEach(items => { ... }); // 'items' shadows outer

// ✅ After
const items = this.allItems;
items.forEach(item => { ... }); // renamed
```

---

### `@angular-eslint/no-lifecycle-call`

**What:** Calling lifecycle hook directly (e.g., `component.ngOnInit()`).

```typescript
// ❌ Before (usually in tests)
component.ngOnInit();

// ✅ After — use fixture
fixture.detectChanges(); // triggers ngOnInit automatically

// ✅ Or if testing a specific method called BY ngOnInit
component.loadData(); // test the method directly
```

---

### `@typescript-eslint/unbound-method`

**What:** Method reference without binding context.

```typescript
// ❌ Before
const fn = this.service.getData; // lost 'this' context
items.map(this.transform); // lost 'this' context

// ✅ After
const fn = this.service.getData.bind(this.service);
items.map(item => this.transform(item));

// ✅ After (arrow function approach — preferred)
items.map((item) => this.transform(item));
```

---

## P5 — Architectural (Skip by Default)

### `@angular-eslint/prefer-standalone`

**SKIP.** This requires converting entire component architecture. Only fix if explicitly requested by user.

### `@angular-eslint/template/no-inline-styles`

**SKIP.** Requires moving styles to SCSS files and may need design decisions.

### `@blackbaud/skyux-eslint-template/*`

**SKIP.** SKY UX-specific template rules that may need design review.

---

## General Fix Principles

1. **Fix the SOURCE, not the symptom.** If `no-unsafe-member-access` fires, fix the `any` that caused it, not just the access.
2. **Chain fixes.** One `any` often causes 3-5 downstream violations. Fix the source and they all clear.
3. **Reuse existing types.** ALWAYS search `shared/interface/` before creating new types.
4. **Smallest change wins.** Don't refactor the whole function — just fix the lint rule.
5. **If it changes behavior, STOP.** Lint fixes must be compile-time only.

---

## Cascading Fix Patterns (Lessons Learned)

These patterns come from real-world fixes where a single change cascades into spec files or downstream code. **Always check for cascading breakage.**

---

### AG Grid `ICellRendererParams` Generics

**Problem:** When you add type parameters to `ICellRendererParams<TData, TValue>` in a component, the spec files break because their mocks use `as ICellRendererParams` (defaults to `<any, any, any>`), triggering `no-unsafe-argument`.

```typescript
// ❌ Component (before)
public agInit(params: ICellRendererParams): void { ... }

// ✅ Component (after)
public agInit(params: ICellRendererParams<unknown, ApprovalRuleCondition[]>): void { ... }

// ❌ Spec breaks:
component.agInit({} as ICellRendererParams); // no-unsafe-argument

// ✅ Spec fix — add matching generics:
component.agInit({} as unknown as ICellRendererParams<unknown, ApprovalRuleCondition[]>);
```

**Workflow:**
1. Fix the component method with generics
2. IMMEDIATELY check the `.spec.ts` for that component
3. Update all `as ICellRendererParams` casts to `as unknown as ICellRendererParams<TData, TValue>`
4. If you use a local interface for TData → **export it** so the spec can import it

---

### Callback `.bind(this)` → Arrow Function Wrapper

**Problem:** `processServerResponse(res, callback, warningCallback)` expects `() => void` but the actual callback has parameters. `.bind(this) as unknown as () => void` is a type-unsafe cast.

```typescript
// ❌ Before — cast hides signature mismatch
this._service.processServerResponse(
  res,
  this.saveWarningCallback.bind(this) as unknown as () => void,
  false,
);

// ✅ After — arrow wrapper preserves type safety
this._service.processServerResponse(
  res,
  (): void => { this.saveWarningCallback(res); },
  false,
);
```

**When `errorCallback` expects `(...args: unknown[]) => void`:**
```typescript
// ✅ Wrap with matching signature
(...args: unknown[]): void => {
  this.saveErrorCallback(args[0], args[1] as string);
},
```

**Rule:** Never use `.bind(this) as unknown as <type>`. Always wrap in a typed arrow function.

---

### `@typescript-eslint/no-confusing-void-expression`

**What:** Placing a `void` return inside another expression (common: `expect(voidFn()).toBeUndefined()`).

```typescript
// ❌ Before — method returns void, expect() wraps it
expect(service.overrideWarning(obj, 21)).toBeUndefined();

// ✅ After — call separately
service.overrideWarning(obj, 21);
// No assertion needed for void methods, or test that it doesn't throw:
expect(() => { service.overrideWarning(obj, 21); }).not.toThrow();
```

**Also appears in arrow returns:**
```typescript
// ❌ Before
items.forEach((item) => component.process(item)); // void in arrow shorthand

// ✅ After — use braces
items.forEach((item) => { component.process(item); });
```

---

### Test Mocks Must Match DOM Types

**Problem:** `HTMLSelectElement.value` is always `string`, but tests mock it with `number`. When the implementation does `Number(event.target.value)`, the test passes accidentally but the mock is wrong.

```typescript
// ❌ Before — number value (wrong DOM type)
{ target: { value: 1 } } as unknown as Event

// ✅ After — string value (matches HTMLSelectElement.value)
{ target: { value: '1' } } as unknown as Event
```

**Rule:** Always use string values when mocking `HTMLInputElement.value` or `HTMLSelectElement.value`.

---

### Unused Callback Parameters (Interface Contracts)

**Problem:** Callback parameters required by an interface but unused in implementation. `_prefix` doesn't always silence `no-unused-vars`.

```typescript
// ❌ Before — unused optional param still triggers lint
public deleteWarningCallback(
  row: FinSimpleRecord,
  _response?: FinResponse<boolean>, // lint: '_response' is defined but never used
): void {
  this.onRowDeleteConfirm(row);
}

// ✅ After — remove if optional and at end of signature
public deleteWarningCallback(
  row: FinSimpleRecord,
): void {
  this.onRowDeleteConfirm(row);
}
```

**Decision tree:**
- If parameter is **optional AND last** → remove it
- If parameter is **required by interface** → keep `_` prefix (verify eslint config allows it)
- If parameter is **in the middle** → keep `_` prefix (can't remove without shifting args)

---

### `@angular-eslint/id-denylist` in Object Literals

**Problem:** Property named `number` (or `string`, `boolean`, etc.) in object literals triggers denylist.

```typescript
// ❌ Before
expenseCategory.accountSummary = {
  number: undefined, // id-denylist: 'number' is restricted

// ✅ After — quote the key
expenseCategory.accountSummary = {
  'number': undefined, // passes lint
```

**Note:** This only applies to object literals/types. Variable names MUST be renamed (can't quote those).

---

### Exporting Interfaces for Spec Access

**Problem:** When typing a component method with a local interface, the spec file can't access it for proper type assertions.

```typescript
// ❌ Component — interface is private
interface BbidRowData { userInfo?: { email?: string } }

// Spec can't reference BbidRowData for proper casting
component.agInit(params as unknown as ICellRendererParams); // falls back to any generics

// ✅ Component — export the interface
export interface BbidRowData { userInfo?: { email?: string } }

// Spec imports and uses it
import { BBIDDetailsCellRendererComponent, BbidRowData } from './bbid-details-cell-renderer.component';
component.agInit(params as unknown as ICellRendererParams<BbidRowData>);
```

**Rule:** If a type is used in a public method signature AND the component has a spec file → export the type.

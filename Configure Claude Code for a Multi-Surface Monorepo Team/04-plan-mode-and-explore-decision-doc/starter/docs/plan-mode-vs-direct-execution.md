# Plan mode vs. direct execution — team decision guide

Choosing between Claude Code's **plan mode** (investigate and propose before changing anything) and **direct execution** (change code immediately) is the single biggest leverage point in how the team uses the harness day-to-day. The wrong mode at either extreme costs us: plan mode for trivial fixes is friction; direct execution for architectural changes burns context and produces rework.

> **Framing: Knight-Webb, "SWE Is Becoming Plan and Review."** The talk's argument is that as agents take over more of the typing, the engineer's leverage moves to the two ends of the loop: deciding what should be built before any code is written, and reviewing what came back. Choosing a mode is how we apply that here — plan when the decision is the hard part, execute when it isn't.
>
> *Source: anchor-talks table in the Module 8 curriculum doc.*

This doc walks four concrete decisions against our codebase: one plan-mode example, one direct-execution example, one Explore-subagent example, and one combined-workflow example.

---

## 1. Plan-mode example

**Task:** extract a shared `useCart(userId)` hook. Three components each fetch the cart and derive totals on their own:

- `src/components/Cart/Cart.tsx` — fetches with an `active` flag that drops stale responses, tracks `loading`, and also mutates via `updateQuantity`.
- `src/components/Checkout/Checkout.tsx` — fetches with no stale-response guard and no loading state.
- `src/components/MiniCart/MiniCart.tsx` — same unguarded fetch, plus an `itemCount` the other two don't compute.

All three repeat the same `total` reducer. The new hook would live in a new file under the hooks directory (src/hooks/useCart.ts, which does not exist yet), and `src/components/Cart/Cart.test.tsx` has to keep passing.

**Why plan mode:** the duplication looks mechanical, but the three copies are not the same, so the extraction forces decisions that have more than one valid answer:

- **Return shape.** Does the hook return just `items`, or also `loading`, `total`, `itemCount`, and a `setQuantity` mutator? Only Cart needs the last one.
- **Behavior change.** Adopting Cart's stale-response guard everywhere changes how Checkout and MiniCart behave when `userId` changes mid-fetch. Probably a fix, but it should be a decision, not a side effect.
- **Hook or context.** Our frontend standards route app-wide state through `CartContext`. Three components fetching the same cart independently is arguably a context problem, not a hook problem — and that answer produces a very different diff.

This is the profile plan mode exists for: a multi-file modification, multiple valid approaches, and an architectural decision underneath. Settling the hook's shape in a plan costs a few minutes of reading; discovering after three components are rewritten that it should have been a context provider means redoing all three. Planning first is how we prevent costly rework.

**What the plan should contain:** the proposed signature and return type, the chosen answer to each question above, the edit order (hook first, then one component at a time), and which tests cover each step.

---

## 2. Direct-execution example

**Task:** remove the redundant empty-order check from `handle` in `src/api/orders/handler.ts`.

The handler parses the body with `orderCreateSchema`, then immediately checks `body.items.length === 0` and throws `EMPTY_ORDER`. That branch can never run: the shared orders schema already declares the items array with `.min(1)`, so an empty array fails at `parse`. Our API standards also say not to re-validate a parsed body downstream.

**Why direct execution:** this is a simple, well-scoped change in one function. There is no design question — the check is dead code and the standard says to delete it. Nothing else in the repo references `EMPTY_ORDER`.

**The bar:** you already know what the diff looks like before you invoke Claude. Here it is four deleted lines (the `if` block and its blank line), plus the `ApiError` import if nothing else in the file uses it. If you can describe the change in one sentence and predict the patch, skip planning — a plan would only restate what you already know.

If the prediction turns out wrong (the diff touches a second file, or Claude starts asking design questions), that is the signal to stop and switch to plan mode.

---

## 3. Explore-subagent example

**Task:** "find every place we call `processRefund`, and what each caller does around it."

This is a discovery question, not a change. Answering it means grepping, opening each hit, and reading the surrounding code — a lot of file content that matters for about thirty seconds and then never again.

**Why the Explore subagent:** it isolates verbose discovery output. The subagent does the searching and reading in its own context and returns only a summary, so the main conversation keeps its context for the work that follows. Run the same search inline and every file read stays in the main session for the rest of the conversation.

**What comes back** is short:

- Defined in `src/services/payment.ts`.
- Called from `src/api/orders/refund.ts`, right after the order lookup.
- Called from `src/api/billing/issue.ts`, same shape.
- No other callers; no dynamic or re-exported references.

**Use the scratchpad pattern.** Following the Architect's Playbook, have the subagent write its full inventory — each call site, the arguments passed, how the result is used — to a scratchpad file (for example tmp/refund-callsites.md) and return the summary plus that path. The scratchpad keeps the detail available without it sitting in context: the inventory survives a compaction or a fresh session, and a later step can re-read just the part it needs.

Example prompt:

> Use the Explore subagent to find every call to `processRefund`. Write the full inventory to a scratchpad file at tmp/refund-callsites.md, and report back only the list of files and anything that looks inconsistent between callers.


---

## 4. Combined workflow — plan mode for investigation, then direct execution

**Task:** rename `ordersRepo.findById` to `ordersRepo.getById` in `src/db/orders.ts`, to match the team naming convention (`get*` for single-row reads, `find*` for multi-row).

**Why a combined workflow:** plan mode and direct execution are not a binary choice. This task has two halves with different profiles:

- **The discovery half is uncertain.** Where is `findById` called, and is any call dynamic — a constructed property lookup like `ordersRepo[name]` that a plain grep would miss? You don't know the call-site list yet.
- **The mechanical half is not.** Once the list is known, the rename is keystrokes.

So use each mode for the half it fits — combining plan mode for investigation with direct execution for implementation:

1. **Plan mode investigates and proposes.** Claude searches for callers and for dynamic access, changing nothing. In this repo the plan comes back with the definition in `src/db/orders.ts` and two callers, `src/api/orders/refund.ts` and `src/api/billing/issue.ts`, with no dynamic lookups.
2. **You approve the plan.** This is the review point: check that the list is complete and that nothing outside it (docs, an external consumer) depends on the old name. If the list had come back with twenty callers or a dynamic lookup, you would stay in plan mode and rethink.
3. **Direct execution applies the rename and runs tests.** Three files, one identifier, then the test suite.

Plan mode then direct execution gets you the safety of planning where the risk is — a missed caller — without the friction of planning where there is none.

---

## Quick reference

| Situation | Mode |
|-----------|------|
| Single function, fix is obvious, you can predict the diff | Direct execution |
| Multi-file refactor, API shape is debatable | Plan mode |
| Discovery / inventory across the codebase, you'll throw away the intermediate steps | Explore subagent |
| Investigation-then-mechanical-change | Plan mode → direct execution |
| Architectural decision (which database, which queue) | Plan mode, possibly with a fork to compare options |

When in doubt: plan mode is recoverable (you can switch to execution), but direct execution on a complex change is not. Default to plan when uncertain.

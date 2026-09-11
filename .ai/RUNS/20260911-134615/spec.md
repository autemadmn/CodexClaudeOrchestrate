# Unit tests for slugify() and truncate() in orchestrator/util.mjs

# Spec: unit tests for `slugify()` and `truncate()`

## Goal
Add one new test file, `orchestrator/test/util.test.mjs`, covering the two pure helpers exported by `orchestrator/util.mjs`. Strictly additive: exactly one file created, zero files modified. Verified by `npm test`.

## Scope
- Create `orchestrator/test/util.test.mjs`.
- Test `slugify(text, max = 40)` and `truncate(text, max)` against their **actual implemented behavior** (`orchestrator/util.mjs:60-64` and `orchestrator/util.mjs:70-78`).

## Non-goals
- Modifying `orchestrator/util.mjs`, `package.json`, existing tests, CI, or any other file — including "obvious" fixes for the quirks listed below (report them, do not fix).
- New dependencies or test frameworks (`node:test` + `node:assert/strict` only).
- Tests for other `util.mjs` exports (`globToRegExp`, `matchesAny`, `globsOverlap`, `readJson`, …) — `planner.test.mjs` already covers the glob helpers.

## Required file conventions
- Path must match the npm test glob `node --test orchestrator/test/*.test.mjs`.
- Match the existing idiom (see `orchestrator/test/planner.test.mjs:1-5`): ESM, flat top-level `test("...", () => {...})` calls (no `describe`), `import { test } from "node:test"`, `import assert from "node:assert/strict"`, `import { slugify, truncate } from "../util.mjs";`.
- Deterministic, no filesystem/network/temp dirs, no timers. (Importing `util.mjs` runs `findRepoRoot()` at module load; this is pre-existing and harmless — do not work around it.)

## Behavior under test (verified from source)

### `truncate(text, max)`
```js
if (!text) return "";
if (text.length <= max) return text;
return text.slice(0, max) + `\n... [truncated ${text.length - max} chars]`;
```
1. Falsy input returns `""` — `""`, `undefined`, `null`, `0` all yield `""` (no throw).
2. `text.length < max` returns the input unchanged.
3. Boundary `text.length === max` returns the input unchanged (no suffix).
4. `text.length > max` returns exactly the first `max` chars plus the suffix `"\n... [truncated N chars]"`, where `N === text.length - max`. Assert the full string exactly, e.g. `truncate("abcdef", 5) === "abcde\n... [truncated 1 chars]"`.
5. `max === 0` with non-empty text returns `"\n... [truncated 3 chars]"` for `"abc"` (empty prefix, suffix still appended).
6. Multi-line input: the slice is byte-for-byte `slice(0, max)`; newlines inside the text are not special.

### `slugify(text, max = 40)`
Pipeline: `toLowerCase()` → replace each run of `[^a-z0-9]+` with a single `-` → strip leading/trailing `-` → `slice(0, max)` → `|| "objective"`.
1. `slugify("Hello World") === "hello-world"`.
2. Runs collapse and edges are trimmed: `slugify("  ---Hello,   World!!! ---  ") === "hello-world"`.
3. Digits survive: e.g. `slugify("TASK-001 Fix Bug") === "task-001-fix-bug"`.
4. Already-slug input is unchanged (idempotent for `hello-world`).
5. Non-ASCII is dropped, not transliterated: `slugify("café") === "caf"`; a purely non-ASCII string such as `"日本語"` yields the fallback `"objective"`.
6. Fallback `"objective"` for `""`, `"!!!"`, `"---"`, and for `slugify("hello world", 0)`.
7. Default `max` is 40: `slugify("a".repeat(50)) === "a".repeat(40)`; explicit max works: `slugify("hello world", 5) === "hello"`.
8. **Trim-before-slice quirk (must be covered):** truncation happens *after* the edge-dash trim, so the result can end with `-`. With `"a b c d e f g h i j k l m n o p q r s t u"` (21 single-letter words) the untruncated slug is 41 chars and `slugify(...)` returns a 40-char string ending in `"-"`. Assert the real value; do not assert a re-trimmed value.

## Edge cases / current-behavior notes
- `slugify(undefined)` / `slugify(null)` throw `TypeError` (no guard, unlike `truncate`). Optionally assert with `assert.throws(() => slugify(undefined), TypeError)`; if included, label the test as documenting current behavior.
- `truncate("abc")` with `max` omitted returns `"abc\n... [truncated NaN chars]"`, and a negative `max` drops trailing chars while reporting an inflated count. These are latent quirks: **report in the task summary, do not encode as tests, do not fix.**

## Definition of done
`npm test` exits 0 with all pre-existing tests still passing, `git status --porcelain` shows exactly one added file (`orchestrator/test/util.test.mjs`) and no modifications.

## Acceptance criteria
- `orchestrator/test/util.test.mjs` exists, is the only file added, and no existing file is modified (`git status --porcelain` shows a single `??`/`A` entry and zero `M` entries).
- The file uses only `node:test` and `node:assert/strict`, imports the helpers via `import { slugify, truncate } from "../util.mjs";`, and uses flat top-level `test()` calls matching `orchestrator/test/planner.test.mjs` and `guardrails.test.mjs`.
- `npm test` exits 0; all pre-existing tests in guardrails/planner/routing still pass; the new file's tests are reported as passing by the node:test runner.
- truncate coverage: falsy inputs (`""`, `undefined`, `null`, `0`) all return `""`; shorter-than-max returns input unchanged; `text.length === max` returns input unchanged with no suffix; longer-than-max returns exactly `text.slice(0, max) + "\n... [truncated N chars]"` with N = length - max asserted as a full exact string; `max === 0` on non-empty text returns the suffix with an empty prefix.
- slugify coverage: basic lowercase/space case; collapsed punctuation runs with leading/trailing dashes trimmed; digits preserved; already-slug input unchanged; non-ASCII dropped (`"café"` -> `"caf"`); `"objective"` fallback for empty/punctuation-only input and for `max === 0`; default max of 40 and an explicit custom max.
- The trim-before-slice quirk is covered by a test asserting the real 40-char result ending in `"-"` for a 21-single-letter-word input.
- No new dependency is introduced; `package.json` and `package-lock.json` are untouched.
- Tests are deterministic: no filesystem writes, no network, no timers, no dependence on cwd or clock; repeated `npm test` runs give identical results.
- Any latent quirk found in `util.mjs` (e.g. `truncate` with omitted or negative `max`, `slugify` throwing on `undefined`) is reported in the worker/manager summary rather than fixed in `util.mjs`.

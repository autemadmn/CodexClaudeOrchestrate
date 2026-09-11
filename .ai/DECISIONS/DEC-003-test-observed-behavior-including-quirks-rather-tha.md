# DEC-003 Test observed behavior, including quirks, rather than fixing util.mjs

## Context
slugify() and truncate() have several rough edges (NaN char count when max is omitted, trailing '-' after max truncation, TypeError on non-string input). The objective forbids modifying util.mjs.

## Decision
Assert the current, observed behavior in the new test file, and explicitly cover the trim-before-slice trailing-dash case. Report the omitted-max/negative-max quirks in the summary as technical debt without encoding them as tests and without changing util.mjs.

## Reason
Keeps the change strictly additive, gives the helpers a regression baseline, and avoids locking clearly accidental behavior (NaN counts) into the suite as if it were a contract.

## Alternatives
- Fix the quirks in util.mjs and test the fixed behavior (violates the objective's no-modification constraint)
- Skip the quirky cases entirely (loses the most valuable regression signal, e.g. the trailing-dash case that affects branch names)
- Assert every quirk including the NaN message (cements accidental behavior as an intended contract)

## Consequences
A future intentional fix to slugify's slice order will fail the trailing-dash test; that failure is the intended signal and the test should be updated alongside the fix. The unasserted quirks remain documented only in the run summary and this spec.

_Recorded by product-architect-manager in run 20260911-134615._

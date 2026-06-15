# Review PR — detailed lens checklist

Expanded checklist for each review lens. Consult this when a diff is non-trivial
or you want to be exhaustive. Not every item applies to every PR — use judgment
and skip what is irrelevant. Map each real finding back to a criticality
(High / Medium / Low) per the rubric in `SKILL.md`.

## Lens 1 — Feature correctness

- [ ] The change implements exactly what the PR body / linked issue describes.
- [ ] Happy path is correct for representative inputs.
- [ ] Edge cases handled: empty, null/None, zero, negative, very large, unicode,
      duplicates, boundary values (off-by-one).
- [ ] Error paths: failures are caught, surfaced, and not silently swallowed.
- [ ] No regression to existing behavior; backward-compatible (API, schema, config,
      serialized formats, public contracts).
- [ ] Idempotency where the operation may be retried.
- [ ] State is left consistent if the operation fails partway (no partial writes).
- [ ] Tests exist and actually exercise the new behavior, not just the happy path.
- [ ] Tests cover the failure/error branches and at least one edge case.
- [ ] No flaky patterns in tests (real sleeps, network calls, time/ordering deps).

## Lens 2 — Design quality

- [ ] Logic lives in the right layer/module; the wrapper/controller/view stays thin.
- [ ] Single responsibility: functions/classes do one thing at one level of abstraction.
- [ ] Names reveal intent; no misleading or abbreviation-heavy identifiers.
- [ ] No copy-paste duplication that should be a shared helper (and no premature
      abstraction of a one-off).
- [ ] Interfaces/contracts are explicit and minimal; callers aren't forced to know internals.
- [ ] Coupling is loose; dependency direction is sane (no upward/circular deps).
- [ ] Consistent with existing patterns, file layout, and conventions in this repo.
- [ ] No dead code, commented-out blocks, or leftover debug statements.
- [ ] Comments explain *why*, not *what*; no narration of obvious code.
- [ ] Public surface (exports, args, return types) is the smallest it can be.
- [ ] Errors/exceptions are typed/specific, not catch-all.

## Lens 3 — Scalability & future-proofing

- [ ] No N+1 queries or per-item network/db calls inside loops.
- [ ] No unbounded collections, recursion, or memory growth with input size.
- [ ] Hot paths avoid accidental O(n²) (nested scans, repeated lookups in lists).
- [ ] Large result sets are paginated/streamed, not loaded whole into memory.
- [ ] DB access has appropriate indexes; queries are selective; no full scans on growth.
- [ ] Caching is used where repeated work is expensive — and invalidation is correct.
- [ ] Connection/thread/file-handle/resource pools are bounded and released.
- [ ] Concurrency: shared state is protected; no data races; locks are scoped tightly.
- [ ] Timeouts, retries (with backoff), and circuit-breaking on external calls.
- [ ] Hard-coded limits / magic numbers are named constants or externalized config.
- [ ] The design admits the *next* likely feature without a rewrite (extension points).
- [ ] Schema/data changes have a migration and a versioning/rollback story.
- [ ] Feature flags / config defaults are safe and reversible.
- [ ] Observability: meaningful logs, metrics, and traces at scale-relevant points;
      log volume won't explode under load.
- [ ] Failure modes degrade gracefully (fallbacks, partial availability).

## Baseline (always)

- [ ] Security: injection (SQL/command/template), authz/authn checks, no secrets in
      code or logs, safe deserialization, SSRF/path-traversal, dependency risk.
- [ ] Input validation at trust boundaries.
- [ ] Project rules honored: repo `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, lint
      configs, CONTRIBUTING, CODEOWNERS expectations.
- [ ] No PII / customer data / internal identifiers leaked into the wrong place.

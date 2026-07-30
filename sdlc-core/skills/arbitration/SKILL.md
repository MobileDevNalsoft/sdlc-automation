---
name: arbitration
description: Use when two pipeline stages (plan vs. implementation, verify vs. review, or two stack plugins) disagree about a convention or fact — writes the conflict to docs/decisions/ for the human, rather than letting whichever agent ran second silently overwrite the other.
---

# arbitration

**Verb: arbitrate.**

## When this fires

- `sdlc-review` finds the implementation diverged from what `sdlc-plan` specified, and the divergence looks intentional rather than a bug.
- Two stack skills disagree about a shared convention (e.g. `schema-architect` assumes `CACHE 20 NOORDER` on every new sequence, but a project's existing sequences were created `NOCACHE ORDER`, and it's unclear which the new one should match).
- A vendored source and this project's own past decision conflict (e.g. `bulletproof-react`'s docs recommend a folder layout the project deliberately deviated from).

## What it is not for

Routine implementation choices with an obvious right answer, or anything `sdlc-verify`/`sdlc-review` can resolve by simply reading a convention doc. Escalate only genuine disagreements — over-escalating trivial calls defeats the point as badly as under-escalating real ones.

## Procedure

1. State both positions in one line each, with their evidence (`file:line` or command output — see `evidence-contract`).
2. State the concrete consequence of picking each side (not "this seems better," but what breaks or what's inconsistent if you pick wrong).
3. Do **not** pick a winner. Write the conflict to `docs/decisions/<short-slug>.md`:

```markdown
# Decision needed: <short title>

## Position A
<claim> — evidence: <file:line or command+output>

## Position B
<claim> — evidence: <file:line or command+output>

## Consequence of each
- If A: <what follows>
- If B: <what follows>

## Status
OPEN — awaiting human decision
```

4. Reference this file's path in the dispatching agent's own output so the human sees it without having to go looking.
5. Once the human decides (by editing the file or replying elsewhere), the next pipeline run reads `docs/decisions/<slug>.md`'s `Status` line — `RESOLVED: <choice>` — and treats that as settled convention going forward, citing the decision file as its evidence.

## Why never resolve it silently

Whichever agent runs second in a pipeline has no more authority than the one that ran first — resolving a real conflict by "the later agent wins" is indistinguishable from a coin flip to the human reviewing the walkthrough, and it hides genuine ambiguity behind an appearance of confidence.

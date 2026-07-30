---
description: Run the full sdlc pipeline (plan -> approve -> implement -> gate+review in parallel -> walkthrough) for one task.
argument-hint: "[task-id or task description]"
---

Run the SDLC automation pipeline for one task, end to end, stopping at the points where a human decision is required.

1. **Establish the task.** Take it from `$ARGUMENTS` — either a task id you can look up in whatever tracker this project uses, or a plain description of the work. If `$ARGUMENTS` is empty, ask what the task is; don't guess from recent context or the working tree.
2. **Check the serial-execution lock.** One task in flight at a time — there is no branch isolation here, so two tasks in one working tree interleave indistinguishably by review time. Before starting, confirm both:
   - no walkthrough under `docs/walkthroughs/` has a non-terminal `Status` (i.e. `BLOCKED`, or missing a status line), and
   - no plan under `docs/plans/` is still awaiting approval or mid-implementation.

   If either exists, name it and stop. Do not start a second task on top of unfinished work.
3. **Plan.** Dispatch the `sdlc-plan` agent with the task. It writes `docs/plans/<task-id>.md` and chooses an execution strategy (inline vs. subagent-driven). Present its output verbatim.
4. **Stop and wait for explicit human approval of the plan.** If it returned `NEEDS-DECISION`, resolve the named decision with the human and re-run `sdlc-plan` before going further — never proceed past an open decision by picking a default.
5. **Implement.** Dispatch `sdlc-developer` with the approved plan path. It honors the plan's execution strategy. If it returns a `SCOPE-REQUEST` (it needs a file the plan didn't list), relay that to the human and wait for their answer — an approval covers only that file for that edit.
6. **Gate.** On `IMPLEMENTED`, dispatch `sdlc-verify` and `sdlc-review` against the same diff, **in parallel** — chaining them means a security finding can't surface until the build is green, which hides one class of problem behind another. Both establish the diff themselves via read-only git.
7. **Handle routed failures.** If either gate returns a `ROUTE-TO-DEVELOPER` block, send it to `sdlc-developer` as a continuation of the same task, then re-run both gates **once**. That re-run does not consume `sdlc-verify`'s 2-cycle budget. If a security fix breaks the build, the walkthrough goes `RED` stating both facts — do not revert the fix to force a green result.
8. **Write the walkthrough.** Invoke the `walkthrough` skill to write `docs/walkthroughs/<task-id>.md` from both agents' verbatim output, including its mandatory manual-verification steps and `Not done` sections.
9. **Update the tracker,** if this project has one — status transitions are a human-visible side effect, so say what you changed. If there's no tracker wired up, say that plainly rather than silently skipping the step.
10. **Present the walkthrough and the uncommitted diff.** **Stop here — do not commit, push, or otherwise mutate git state.** That is always a human action.

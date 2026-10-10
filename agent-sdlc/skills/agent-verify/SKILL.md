---
name: agent-verify
description: Runs the automated verification gate for multi-agent systems — enforces strict type safety (mypy), code style (ruff), deterministic tool schema validation, state transition test execution (pytest), and guardrail safety checks. Emits GATE-PASS or GATE-FAIL with verbatim error output.
---

# agent-verify

**Verb: verify-agent.**

## 1. Non-Negotiable Gate Criteria

An agent application slice passes verification ONLY when:
1. `ruff check .` exits 0 with zero lint or import errors.
2. `mypy src` exits 0 with zero type violations across all graph state schemas.
3. `pytest tests/` passes 100% of unit tests asserting:
   - Tool arguments match Pydantic schemas.
   - Graph compiles without unbound nodes or dangling edges.
   - Checkpointer correctly persists and resumes thread state.
4. No hardcoded API keys or plaintext credentials exist in source code.

## 2. Gate Execution

```bash
# Style & Boundary Lint
ruff check .

# Static Type Verification
mypy src

# Deterministic Test Suite
pytest -v
```

If any check fails, report `GATE-FAIL: [Command and failure details]`.
When all checks succeed, emit `GATE-PASS`.

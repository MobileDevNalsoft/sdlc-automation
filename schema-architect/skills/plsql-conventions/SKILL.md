---
name: plsql-conventions
description: Use whenever an agent is about to write, review, or approve PL/SQL — a procedure, function, package, trigger, cursor, or local variable — in a schema-architect or api-architect task. The naming contract (procedure/function/package suffixes, scope prefixes for variables and parameters), the large-data mechanics (BULK COLLECT LIMIT, CLOB assembly, ref cursor vs materialized payload), and the correctness rules (bind variables, exception handling, package-global purity under pooled connections) live in PLSQL-CONVENTIONS.md as rules P1-P20. Load before api-emit-handler generates a handler and before any review of a .sql/.pks/.pkb diff.
---

# plsql-conventions

**Verb: conform.**

## What this skill is

A lookup, not a generator — the same shape as `api-architect:api-contract`.
The rules live in **`PLSQL-CONVENTIONS.md`** in this directory as **P1–P20**.
Read that file; this SKILL.md only says when to load it and how to cite it.

It sits in `schema-architect` because PL/SQL is database code, but it is
**consumed by both plugins**: `api-architect:api-emit-handler` writes the
packages that ORDS handlers call, and every one of them is bound by these
rules.

## Why this exists separately from schema-model

`schema-architect:schema-model` §0 already owns the naming contract for
**data objects** — tables, constraints, indexes, sequences, triggers. It
deliberately says nothing about **program units**, and that gap is why a
procedure could be called `get_orders`, `getOrders`, `p_get_orders`, or
`get_orders_p` in four files of the same schema with nothing to appeal to.

This skill owns the program-unit half. Together they are the complete naming
contract. Neither restates the other — if you need a table name, that is
schema-model §0; if you need a procedure name, it is P1 here.

## When to load this

- Before `api-architect:api-emit-handler` generates an engine procedure — its
  templates encode these rules, but the dispatching agent should know which
  rule is which when explaining a deviation.
- Before writing any package spec/body, trigger, or standalone program unit.
- During review of any `.sql` / `.pks` / `.pkb` diff — cite the violated `P#`
  by number rather than restating the prose.
- When a payload might be large — **P10–P14 are the large-data rules**, and
  they are the ones most often skipped until production memory errors force
  the issue.

## How to cite

By ID, not paraphrase. `"violates P12: BULK COLLECT with no LIMIT — unbounded
PGA growth"` is a review comment; `"this might use a lot of memory"` is not.

## The naming convention is a PARAMETER, not a law

P1's table ships **this shop's convention** (`_p` for procedures, `_f` for
functions) as the default, because a default nobody can act on is useless.
But like schema-model §0, it is a parameter you read once and hold constant
for the session.

**If the target schema already uses a different convention, match it.** A new
`get_orders_p` sitting next to two hundred existing `get_orders` procedures is
drift, not improvement — exactly what `schema-audit` exists to catch. Record
which convention you're using in the plan output.

The most widely cited public alternative is the **Trivadis PL/SQL & SQL Coding
Guidelines**, which use a `{prefix}content{suffix}` pattern with scope
prefixes (`g_` global, `l_` local, `p_` parameter, `c_` constant/cursor,
`r_` record). `ASSUMPTION:` that summary comes from secondary sources — the
Trivadis documentation site returned HTTP 404 on every URL tried on
2026-07-31, so the full table was **not** fetched and is not reproduced here.
Verify against the current upstream before adopting it wholesale.

Note the collision this creates and P1 resolves: `p_` as a *parameter prefix*
(Trivadis) and `_p` as a *procedure suffix* (this shop) are different
conventions occupying similar-looking space. They are compatible because one
is a prefix on variables and the other a suffix on program units — but only
if you say so explicitly, which P1 does.

## Cross-references

- `schema-architect:schema-model` — the data-object half of the naming
  contract (§0). Read both; neither is complete alone.
- `api-architect:api-contract` — the HTTP-level contract (A1–A23). Where a
  rule here concerns the shape of a response body, A23 governs the wire
  format and P10–P14 govern how PL/SQL produces it without running out of
  memory.
- `api-architect:api-audit` — its package-global scan is the automated check
  for **P17**; that rule explains why the scan exists.

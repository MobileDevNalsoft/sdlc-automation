---
name: agent-bootstrap
description: Scaffolds a production-grade multi-agent application (LangGraph, CrewAI, or StateGraph) with strongly-typed State, deterministic tool schemas, checkpointing persistence (Postgres/SQLite), human-in-the-loop review interrupts, and the complete 10-document context suite via docs-scaffold. Use when creating greenfield AI agent systems or adopting resilient orchestration conventions into existing agent scripts.
---

# agent-bootstrap

**Verb: scaffold-agent.**

## 1. What "Production-Grade" Means for AI Agents

Most AI agent demos fail in production because they rely on unbounded loops, unvalidated tool outputs, and in-memory states that vanish on crash. This skill enforces five architectural invariants:

1. **Deterministic State Graph**: The workflow is modeled as a compiled `StateGraph` where every transition is governed by explicit conditional edges.
2. **Strict Schema Contracts**: Every tool argument and agent state field is validated via Pydantic v2 models.
3. **Persistent Checkpointing**: State transitions are serialized to SQLite or PostgreSQL, enabling resume-on-failure and time-travel debugging.
4. **Human-in-the-Loop (HITL) Gateways**: Destructive actions (database writes, deletions, payments, external API calls) pause execution at an explicit interrupt node until human sign-off.
5. **Context Firewalling**: Subagents carry focused tool allowlists (never `*`), strict system prompts under 4 KB, and return only structured summaries to the supervisor.

---

## 2. Directory Layout Contract

```
<project-root>/
├── docs/                      # Emitted by docs-scaffold
│   ├── PRD.md
│   ├── UX_FLOWS.md
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   ├── TESTING.md
│   └── ...
├── src/
│   ├── agents/                # Node definitions & subagents
│   │   ├── supervisor.py
│   │   └── research_agent.py
│   ├── graph/                 # StateGraph definition & edges
│   │   ├── state.py           # TypedDict / Pydantic AgentState
│   │   ├── edges.py           # Conditional routing logic
│   │   └── workflow.py        # Graph assembly & compile()
│   ├── tools/                 # Pure tool implementations & schemas
│   │   ├── registry.py
│   │   └── search_tool.py
│   ├── persistence/           # Checkpointer configuration
│   │   └── checkpointer.py
│   └── config.py              # Settings via pydantic-settings
├── tests/
│   ├── test_graph.py
│   └── test_tools.py
├── pyproject.toml             # Ruff, mypy, pytest config
├── AGENTS.md                  # Emitted by docs-scaffold
└── README.md
```

---

## 3. Core Graph & State Implementation Patterns

### Strongly-Typed Agent State (`src/graph/state.py`)
```python
from typing import Annotated, Sequence, TypedDict
from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    """Immutable state schema passed between all graph nodes."""
    messages: Annotated[Sequence[BaseMessage], add_messages]
    next_step: str
    requires_approval: bool
    context_data: dict
```

### Human-in-the-Loop Interrupt Pattern (`src/graph/workflow.py`)
```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver

def create_agent_workflow(db_path: str = "checkpoints.db"):
    memory = SqliteSaver.from_conn_string(db_path)
    workflow = StateGraph(AgentState)

    # Register nodes
    workflow.add_node("supervisor", supervisor_node)
    workflow.add_node("tool_executor", tool_executor_node)
    workflow.add_node("human_review", human_review_node)

    # Wire conditional edges
    workflow.set_entry_point("supervisor")
    workflow.add_conditional_edges(
        "supervisor",
        route_supervisor_decision,
        {
            "tools": "tool_executor",
            "review": "human_review",
            "end": END
        }
    )

    # Require human approval before running mutative tools
    return workflow.compile(
        checkpointer=memory,
        interrupt_before=["human_review"]
    )
```

---

## 4. Scaffolding Procedure

1. **Generate Documentation Suite**: Dispatch `docs-architect:docs-scaffold` targeting `agent` profile to emit `docs/` and root `AGENTS.md`.
2. **Emit Project Skeleton**: Generate `pyproject.toml` with pinned dependencies (`langgraph>=0.2.20`, `langchain-core>=0.3.0`, `pydantic>=2.8.0`, `ruff>=0.5.0`, `mypy>=1.11.0`, `pytest>=8.3.0`).
3. **Emit Graph & State Core**: Scaffold `src/graph/state.py`, `src/graph/workflow.py`, and `src/tools/`.
4. **Emit Automated Tests**: Unit tests asserting deterministic graph routing and state preservation.
5. **Execute Verification Gate**:
   - `ruff check .`
   - `mypy src`
   - `pytest`

---
name: agent-slice
description: Implements one vertical slice in a multi-agent application — adds a new specialized agent node, a tool with Pydantic validation, or an edge routing branch to an existing StateGraph. Follows strict context-firewalling and schema safety rules.
---

# agent-slice

**Verb: slice-agent.**

## 1. What a Vertical Slice Means in an Agent System

In a multi-agent graph, a vertical slice consists of three connected layers:
1. **The Tool Definition**: A deterministic Python function decorated with `@tool`, backed by a strict `pydantic.BaseModel` schema with typed docstrings.
2. **The Node Function**: A pure or stateful function `node(state: AgentState) -> dict` that executes the model or tool call and updates the state.
3. **The Routing Edge**: A conditional transition or direct edge wiring the new node into the compiled `StateGraph`.

---

## 2. Implementation Rules

1. **Strict Tool Schemas**: Never pass unstructured `*args` or `**kwargs` to tools. Define explicit Pydantic fields with validation constraints and descriptions.
2. **Context Compression**: When a tool returns large payloads (e.g. 50 KB raw JSON), the tool MUST summarize or filter the output before injecting it into `state["messages"]`.
3. **Idempotency & Error Handling**: Tool implementations must handle API timeouts and format errors gracefully, returning structured error messages rather than raising unhandled exceptions.
4. **No Direct Execution**: The node updates state; the checkpointer commits state.

# System Architecture & Technical Specifications

## 1. System Overview & Topology
- **System Architecture**: Vertical Slice Architecture / Clean Architecture.
- **Client Tier**: [React 19 + TypeScript / Flutter / Multi-Agent CLI]
- **API Tier**: [REST / ORDS / Node.js Express / FastAPI]
- **Data Tier**: [Oracle DB / PostgreSQL / SQLite]

```
+-------------+         +------------------+         +---------------+
| UI Client   | <=====> | Reverse Proxy    | <=====> | REST Services |
| (SPA / App) |         | (Docker / Nginx) |         | & Database    |
+-------------+         +------------------+         +---------------+
```

---

## 2. Dependency Rules & Slice Boundaries
1. **Vertical Slices**: Features reside in isolated modules under `src/features/<feature>/` (or `lib/features/<feature>/`).
2. **Zero Cross-Slice Imports**: A feature slice MUST NEVER import from a sibling feature slice. All shared logic promotes to `shared/` or `core/`.
3. **Automated Enforcement**: Enforced by linter rules (`eslint-plugin-boundaries` for React, `check_boundaries.dart` for Flutter). Build fails on violation.

---

## 3. Data Flow & State Lifecycle
1. User interacts with UI component.
2. Component triggers query/mutation hook or BLoC event.
3. API Client injects Bearer token and headers; executes HTTP call.
4. On 401 Unauthorized: client initiates single-flight token refresh; replays queue.
5. On 409 Conflict: client extracts RFC 9457 error payload and triggers conflict resolver.
6. Server processes request; applies optimistic lock checks and soft-delete filters.
7. Server returns DTO with `object_version_number`.
8. UI transformer maps backend `snake_case` DTO to frontend `camelCase` domain model.
9. Cache updates; UI renders loaded state.

---

## 4. Architectural Decision Records (ADRs)
### ADR-001: [Title - e.g. Adoption of Optimistic Concurrency Control]
- **Status**: Accepted
- **Context**: High-concurrency record editing where pessimistic row locks degrade connection pooling.
- **Decision**: Require `object_version_number` checks on all UPDATE and DELETE mutations.
- **Consequences**: Avoids long-lived locks; UI must handle 409 Conflict gracefully.

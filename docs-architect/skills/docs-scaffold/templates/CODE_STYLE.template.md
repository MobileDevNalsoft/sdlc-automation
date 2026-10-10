# Code Style & Structural Conventions

## 1. Core Principles
- **Clarity Over Cleverness**: Code must be immediately comprehensible to peer reviewers.
- **Single Responsibility**: Every module or component does one logical thing well.
- **Zero Drift**: Follow established patterns within the codebase; never introduce duplicate utilities.

---

## 2. Feature Slice Boundaries
- **Directory Layout**:
  ```
  src/features/<feature-name>/
    ├── api/           # DTOs, endpoint callers, query hooks
    ├── components/    # Feature-specific UI components
    ├── hooks/         # Feature-specific state logic
    └── types/         # Domain models & state unions
  ```
- **Boundary Invariant**:
  - `src/features/a` CANNOT import from `src/features/b`.
  - Shared logic MUST be promoted to `src/shared/`.
  - Enforced automatically by linter boundary rules.

---

## 3. UI State Discipline (5 States)
Every async data-rendering component must explicitly handle:
1. `loading`: Skeleton placeholder matching target geometry.
2. `empty`: `EmptyState` component with remediation action.
3. `error`: `ErrorState` component with Retry affordance.
4. `gated`: `PermissionGate` component indicating view-only / missing access.
5. `loaded`: Normal data visualization.

---

## 4. Naming Conventions
- **Components / Classes**: `PascalCase` (`TicketDetailsPanel.tsx`, `EmployeeProfileCard.dart`).
- **Functions / Hooks / Variables**: `camelCase` (`useTicketDetails.ts`, `fetchEmployeeById`).
- **Constants / Enums**: `SCREAMING_SNAKE_CASE` (`MAX_PAGE_SIZE`, `DEFAULT_TIMEOUT_MS`).
- **Files / Directories**: `kebab-case` (`ticket-details-panel.tsx`, `employee-profile/`).
- **Database Tables & Columns**: `snake_case` (`service_tickets`, `ticket_status`).

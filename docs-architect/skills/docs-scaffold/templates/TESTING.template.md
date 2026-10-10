# Testing Strategy & Quality Gates

## 1. Quality Objectives
- **Zero Broken Builds**: CI and pre-commit checks strictly fail on compile errors or lint violations.
- **Coverage Where It Counts**: Prioritize business logic, optimistic locking conflicts, auth guards, and data transformers over superficial UI rendering tests.

---

## 2. Test Pyramid
1. **Unit Tests (Fast, In-Memory)**:
   - Data transformers (`snake_case` -> `camelCase`).
   - Pure business rules and calculation utilities.
   - Form schema validation rules.
2. **Integration Tests**:
   - Query hooks & TanStack Query cache invalidations.
   - BLoC state transitions under simulated API failures.
   - RFC 9457 error payload parsing.
3. **Smoke & E2E Tests**:
   - Critical user flows: Login -> Navigate -> Create record -> Edit record with version increment -> Logout.

---

## 3. Deterministic Verification Commands
Every change must be validated against these exact commands before task completion:

| Command | Target | Non-Negotiable Gate |
|---|---|---|
| `npm run typecheck` | TypeScript compile check | 0 errors (`tsc --noEmit`) |
| `npm run lint` | ESLint boundary & syntax check | 0 errors |
| `npm run test` | Vitest / Jest / Flutter test suite | All tests passing |
| `npm run build` | Production bundle build | Clean build without warnings |

---

## 4. Definition of Done Checklist
- [ ] Code compiles cleanly with zero type errors.
- [ ] No feature boundary violations.
- [ ] All 5 UI states verified.
- [ ] Automated tests passing.
- [ ] Documentation updated to reflect changes.

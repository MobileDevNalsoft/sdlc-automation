# UX Flows & Interaction Specification

## 1. Interaction Principles
- **Predictable Transitions**: Objects never pop into view abruptly; state changes interpolate smoothly.
- **5-State Completeness**: Every screen and async data view must explicitly define:
  1. **Loading State**: Skeleton screen with exact geometry reserved (no layout shift).
  2. **Empty State**: Friendly illustration/message with a primary fixing action button.
  3. **Error State**: Non-technical problem explanation with a Retry action.
  4. **Gated State**: Explicit explanation when user lacks permission (`ACCESS_TYPE='V'`).
  5. **Loaded State**: Complete responsive data view.

---

## 2. Core User Journeys

### Flow 1: [Flow Name - e.g. User Authentication & Onboarding]
- **Entry Point**: [Route / Screen]
- **Steps**:
  1. User arrives at [Route].
  2. Submits [Form/Action].
  3. Frontend validates format synchronously.
  4. API processes request asynchronously.
  5. Redirects to [Destination].
- **States Breakdown**:
  - **Loading State**: [Form buttons disable, inline spinner/skeleton appears].
  - **Empty State**: [Initial state before input or search query].
  - **Error State**: [Field validation banners or RFC 9457 problem modal].
  - **Success State**: [Confirmation toast + redirect].

### Flow 2: [Flow Name - e.g. Record Creation with Concurrency Guard]
- **Entry Point**: [Button on List View]
- **Steps**:
  1. User clicks "Create / Edit".
  2. Drawer / Modal opens with cached or fresh entity.
  3. User edits fields and submits.
  4. Optimistic lock verification: payload sends `object_version_number`.
  5. On 409 Conflict: user receives conflict resolution dialog (Reload vs Overwrite).
  6. On 200/201: local cache invalidated and view updates immediately.

---

## 3. Responsive Breakpoints & Adaptive Rules
- **Desktop (>=1280px)**: Multi-column grid, persistent sidebar navigation.
- **Tablet (768px - 1279px)**: Collapsible rail sidebar, adapted 2-column forms.
- **Mobile (<768px)**: Bottom navigation / slide drawer, single-column stacked controls.

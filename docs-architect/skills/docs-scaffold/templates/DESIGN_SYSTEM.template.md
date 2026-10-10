# Design System & Token Specification

## 1. Design Direction & Visual Grammar
- **Aesthetic Direction**: Professional, high-density enterprise typography, subtle elevation, and calibrated contrast.
- **Theme Default**: Light theme primary, high-contrast dark theme ready.
- **Rule of Tokens**: Zero raw hex colors or ad-hoc style classes in feature code. All visual tokens are declared in the central theme (`tokens.css` for web, `AppTheme` for Flutter).

---

## 2. Color Palette (Semantic Tokens)

| Token Role | Light Mode Value | Dark Mode Value | Usage / Semantics |
|---|---|---|---|
| `bg-app` | `#F8FAFC` | `#0F172A` | Global application canvas background |
| `bg-surface` | `#FFFFFF` | `#1E293B` | Cards, modals, drawers, panels |
| `fg` | `#0F172A` | `#F8FAFC` | Primary readable text (contrast >= 7:1) |
| `fg-muted` | `#475569` | `#94A3B8` | Secondary labels, descriptions (contrast >= 4.5:1) |
| `fg-subtle` | `#94A3B8` | `#64748B` | Disabled elements & decorative icons only |
| `primary` | `#4F46E5` | `#6366F1` | Primary CTA buttons, active tabs, focus rings |
| `success` | `#10B981` | `#34D399` | Positive confirmations, active statuses |
| `warning` | `#F59E0B` | `#FBBF24` | Pending actions, SLA warning alerts |
| `danger` | `#EF4444` | `#F87171` | Destructive actions, 409 conflicts, error alerts |
| `border` | `#E2E8F0` | `#334155` | Dividers, card borders, control boundaries |

---

## 3. Typography Scale

- **Font Family**: Modern sans-serif (Inter, Outfit, or Roboto).
- **Scale**:
  - `text-xs`: 12px / 16px (Badges, metadata tags)
  - `text-sm`: 14px / 20px (Table cells, form inputs, body copy)
  - `text-base`: 16px / 24px (Standard cards, narrative paragraphs)
  - `text-lg`: 18px / 28px (Panel headers, section titles)
  - `text-xl`: 20px / 28px (Modal titles, major headings)
  - `text-2xl`: 24px / 32px (Page headers, dashboard KPI numbers)

---

## 4. Spacing, Radii & Elevation Ladder

### Spacing Scale (4px Base Grid)
- `space-1` (4px), `space-2` (8px), `space-3` (12px), `space-4` (16px), `space-6` (24px), `space-8` (32px).

### Border Radii
- `rounded-control`: 6px / 8px (Buttons, text fields, selects).
- `rounded-card`: 10px / 12px (Content cards, panels).
- `rounded-full`: 9999px (Status pills, avatar badges).

### Stacking Order (Z-Index Ladder)
```
z-10 : Pinned table columns
z-20 : Sticky table headers
z-30 : Application fixed header / topbar
z-40 : Popover / Dropdown menus
z-50 : Drawers, Dialogs, Modals, Toasts
```

---

## 5. Accessibility (WCAG 2.1 AA) Rules
1. **Never Color Alone**: Status pills must pair a dot/icon with a distinct text label.
2. **Keyboard Focus**: All interactive controls carry a visible `2px` focus ring.
3. **Contrast Floor**: Body copy and readable labels must meet >= 4.5:1 contrast against their backing surface.

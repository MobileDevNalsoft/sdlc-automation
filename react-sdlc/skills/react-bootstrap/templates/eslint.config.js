// eslint.config.js — ESLint flat config (ESLint 9/10-compatible).
// Two profiles (greenfield / adopt-in-place) share this file's SHAPE; the
// delta between profiles is dependency VERSIONS (react-bootstrap/SKILL.md's
// version table), not this file's structure.
//
// Pin exact versions in package.json devDependencies (not ^ranges — a config
// this deliberately narrow is only as safe as its pins). Verify current
// numbers with `npm view <package> version` rather than copying old ones:
//   eslint, @eslint/js, typescript-eslint, eslint-plugin-import-x,
//   eslint-plugin-jsx-a11y, eslint-plugin-react-hooks,
//   eslint-plugin-react-refresh, @tanstack/eslint-plugin-query

import js from '@eslint/js';
// TRAP 1 — DO NOT let this float to `latest`.
// `@eslint/js`'s npm `latest` dist-tag always tracks the current ESLint
// major. If this package is ever added/upgraded with
// `npm install @eslint/js@latest` or a bare `^` range gets bumped by an
// unrelated `npm update`, it can silently jump a major and this whole config
// can start failing to load or changing rule defaults out from under you.
// Hand-pin the exact version you tested against.
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import importX from 'eslint-plugin-import-x';
import tanstackQuery from '@tanstack/eslint-plugin-query';
import globals from 'globals';

export default tseslint.config(
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      // Add any other build/tooling-artifact directories your project
      // actually produces (coverage/, .cache/, etc.) — don't carry forward
      // an ignore entry for a build tool your project doesn't use.
    ],
  },

  js.configs.recommended,
  ...tseslint.configs.recommended,

  // TRAP 2 — this is an ARRAY, not a single config object.
  // @tanstack/eslint-plugin-query's flat-config export
  // (`tanstackQuery.configs['flat/recommended']`) is an *array* of config
  // objects. Spread it into the tseslint.config(...) call with `...` — do NOT
  // nest it as `{ ...tanstackQuery.configs['flat/recommended'] }` or push it
  // as one entry. Nesting it silently produces a malformed single config
  // object that ESLint either rejects or partially applies, and the failure
  // mode is quiet (fewer rules firing), not a hard error — easy to miss in
  // review.
  ...tanstackQuery.configs['flat/recommended'],

  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: globals.browser,
      parserOptions: {
        ecmaFeatures: { jsx: true },
        // Deliberately NOT type-aware linting (no `project`/`projectService`)
        // by default — type-aware rules typically roughly double lint run
        // time because they load the full TypeScript program/checker. Turn
        // it on selectively for specific high-value rules once you've
        // measured the cost against your own codebase, not repo-wide by
        // default.
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      'jsx-a11y': jsxA11y,
      'import-x': importX,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // allowConstantExport: many codebases export a constant alongside a
      // component/hook from the same module (a query-key factory next to its
      // hook, a context object next to its provider) — without this,
      // react-refresh flags every one of those as a fast-refresh boundary
      // violation.
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      ...jsxA11y.configs.recommended.rules,
      'import-x/no-duplicates': 'error',
      'import-x/no-self-import': 'error',
      'import-x/no-cycle': 'off',
      // ^ Off by default — turn on and measure the hit count against your
      // own feature-folder import graph before committing to it as a gate
      // rule; it can be expensive to compute on a large graph.
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'off',
      // ^ Off by default here — many codebases' DTO boundary layer
      // (feature/api/*.transformers.ts) leans on `as any` at the raw-response
      // edge deliberately, to isolate an untyped wire format from the typed
      // domain model. If your project doesn't have that pattern, turn this
      // rule back on; it isn't a universal default, it's an escape hatch for
      // one specific boundary.
    },
  },

  // Build-tool/Node-context config files run under Node, not the browser.
  {
    files: ['vite.config.ts', 'postcss.config.js', 'tailwind.config.js', 'scripts/**/*.cjs', 'scripts/**/*.js'],
    languageOptions: { globals: globals.node },
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature-folder boundaries — DOCUMENTATION ONLY. Not a lint rule here.
  // vendored bulletproof-react docs concept on 2026-07-30, source:
  // https://github.com/alan2207/bulletproof-react, license: MIT
  //
  // Intended isolation (see react-bootstrap/SKILL.md's "Folder architecture"
  // section for the full rationale):
  //   - A feature may import from its own subtree, and from shared/.
  //   - A feature must NOT reach into another feature's internals directly.
  //
  // This is intentionally NOT enforced here by `eslint-plugin-boundaries` or
  // an `import/no-restricted-paths`-equivalent rule by default — both are
  // worth adopting, but some glob-based configs for these plugins have been
  // observed to silently no-op on Windows (path normalization can run before
  // the plugin's glob-matching ever sees the pattern, so the rule matches
  // nothing and reports zero violations regardless of real violations
  // present). If you adopt one, prove it fires on a deliberately-broken
  // import in a throwaway commit on every OS your team develops on before
  // trusting it as a gate.
  // ─────────────────────────────────────────────────────────────────────────
);

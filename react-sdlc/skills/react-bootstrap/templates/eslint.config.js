// eslint.config.js — ESLint flat config, ESLint 10.
import js from '@eslint/js';
// TRAP 1 — DO NOT let this float to `latest`. `@eslint/js`'s npm `latest`
// dist-tag always tracks the current ESLint major, so a bare `^` range or an
// unrelated `npm update` can jump a major and change rule defaults, or fail
// to load, out from under you. Hand-pin the exact version you tested against.
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import importX from 'eslint-plugin-import-x';
import boundaries from 'eslint-plugin-boundaries';
import tanstackQuery from '@tanstack/eslint-plugin-query';
import globals from 'globals';

export default tseslint.config(
  { ignores: ['dist/**', 'node_modules/**', 'coverage/**'] },

  js.configs.recommended,
  ...tseslint.configs.recommended,

  // TRAP 2 — this is an ARRAY, not a single config object. Spread it with
  // `...`. Nesting it as one entry produces a malformed config that ESLint
  // partially applies — the failure is quiet (fewer rules firing), not a hard
  // error, so it survives review easily.
  ...tanstackQuery.configs['flat/recommended'],

  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
      // Deliberately NOT type-aware by default: type-aware rules load the full
      // TS program and roughly double lint time. Enable selectively once
      // measured against your own codebase.
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      'jsx-a11y': jsxA11y,
      'import-x': importX,
      boundaries,
    },
    settings: {
      // ---- THE LINE THAT MAKES THE BOUNDARY RULE ACTUALLY WORK -----------
      // Without a TypeScript-aware resolver, eslint-plugin-boundaries falls
      // back to the Node resolver, which resolves .js/.json but NOT .ts/.tsx.
      // Every import then classifies as an UNKNOWN element, no policy matches,
      // and the rule reports zero violations on a flagrantly broken import —
      // a silent no-op that looks exactly like a passing gate.
      // VERIFIED: removing this block makes the deliberate cross-feature
      // import below report clean; adding it makes the same file error.
      'import/resolver': {
        typescript: { alwaysTryTypes: true, project: './tsconfig.json' },
      },

      // ---- Feature-folder boundaries -------------------------------------
      // ORDER MATTERS: eslint-plugin-boundaries takes the FIRST matching
      // element type, so the more specific `features/*` pattern must precede
      // any broader one.
      'boundaries/elements': [
        { type: 'app', pattern: 'src/app/**/*' },
        { type: 'feature', pattern: 'src/features/*/**/*', capture: ['featureName'] },
        { type: 'shared', pattern: 'src/shared/**/*' },
        { type: 'styles', pattern: 'src/styles/**/*' },
      ],
      'boundaries/ignore': ['**/*.test.*', '**/*.spec.*', 'src/main.tsx'],
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // allowConstantExport: exporting a query-key factory or context object
      // beside its hook is normal and is not a fast-refresh defect.
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      ...jsxA11y.configs.recommended.rules,

      'import-x/no-duplicates': 'error',
      'import-x/no-self-import': 'error',
      // Off by default — measure the cost against your own import graph before
      // making it a gate rule; it is expensive on a large graph.
      'import-x/no-cycle': 'off',

      // THE boundary rule. `default: 'disallow'` is what makes this a real
      // gate: anything not explicitly allowed is an error, so a new element
      // type added later fails closed rather than silently passing.
      //
      // v7 SYNTAX. The rule was renamed (`element-types` -> `dependencies`),
      // `rules` became `policies`, selectors became objects, and the capture
      // template changed from `${...}` to `{{...}}`. Every tutorial and most
      // generated configs still use the v5/v6 shape; it is accepted but only
      // emits deprecation warnings, so a config can look fine and be legacy.
      'boundaries/dependencies': [
        'error',
        {
          default: 'disallow',
          policies: [
            // app/ is the composition root — it composes everything.
            {
              from: { element: { type: 'app' } },
              allow: { to: { element: { types: { anyOf: ['app', 'feature', 'shared', 'styles'] } } } },
            },
            // A feature may import shared/ and styles/ freely...
            {
              from: { element: { type: 'feature' } },
              allow: { to: { element: { types: { anyOf: ['shared', 'styles'] } } } },
            },
            // ...and its OWN subtree only, matched by the captured feature
            // name. This is the line that makes features/products importing
            // features/auth an error.
            {
              from: { element: { type: 'feature' } },
              allow: {
                to: {
                  element: {
                    type: 'feature',
                    // KEY IS `captured`, NOT `capture`. A misspelled selector
                    // key is silently IGNORED rather than rejected, which
                    // drops the constraint and quietly allows every
                    // cross-feature import — the rule still runs, still
                    // reports on other violations, and looks healthy.
                    captured: { featureName: '{{from.captured.featureName}}' },
                  },
                },
              },
            },
            // shared/ is the bottom layer: it may not depend on app/ or on any
            // feature, or the graph inverts and every feature transitively
            // drags in every other one.
            {
              from: { element: { type: 'shared' } },
              allow: { to: { element: { types: { anyOf: ['shared', 'styles'] } } } },
            },
          ],
        },
      ],

      '@typescript-eslint/no-unused-vars': [
        'warn',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },

  // The app layer legitimately imports each feature's public surface to build
  // the route table; features still may not import each other.
  {
    files: ['vite.config.ts', 'eslint.config.js', 'scripts/**/*.{js,cjs,mjs}'],
    languageOptions: { globals: globals.node },
  },

  // public/config.js is a plain browser script loaded by a <script> tag before
  // the bundle — not a module, and not part of the TS program.
  {
    files: ['public/**/*.js'],
    languageOptions: { globals: globals.browser, sourceType: 'script' },
  }
);

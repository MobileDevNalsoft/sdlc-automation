// router-migration-example.tsx — react-bootstrap template
//
// Illustrates the ONE change a react-router-dom -> react-router migration
// requires: the import source, not the API surface. Applies when
// react-bootstrap's version table's router branching (based on the target's
// React major) calls for the current 7.x line on a React 18 project.
//
// React 18 projects: react-router-dom@^7.x -> react-router@^7.x (current
// patch — verify at scaffold time). As of the v7 line, the APIs most apps
// already use (BrowserRouter/HashRouter, Routes, Route, Navigate,
// useNavigate, useLocation, useParams, Link, Outlet) are exported from the
// unified `react-router` package; `react-router-dom` is kept only as a
// compatibility re-export. Nothing about HOW these APIs are called changes —
// this is a mechanical import-source rename across every file that imports
// from 'react-router-dom', not a behavioral migration.
//
// React 19 projects: go straight to react-router@8.x. react-router 8
// requires React >=19.2.7, Node >=22.22, and Vite 7+ (Framework Mode), and
// ships ESM-only — do NOT install it against a React 18 / older-Node
// baseline; that's an unsupported combination, not just an untested one.
// Branch on the target's React major, don't default every profile to the
// newest router.

// BEFORE (react-router-dom, any 7.x):
// import { BrowserRouter, Routes, Route, Navigate, useNavigate } from 'react-router-dom';

// AFTER (react-router, matching major):
import { BrowserRouter, Routes, Route, Navigate, useNavigate } from 'react-router';

export function AppRouterExample() {
  const navigate = useNavigate();
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        {/* ...the rest of the project's real route table is unchanged */}
      </Routes>
    </BrowserRouter>
  );
}

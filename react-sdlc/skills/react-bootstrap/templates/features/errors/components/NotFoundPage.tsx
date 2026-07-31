// DESTINATION: src/features/errors/components/NotFoundPage.tsx
//
// PLACEHOLDER — good enough to keep as-is for most projects (a 404 page
// rarely needs real feature work), but replaceable via react-sdlc:react-slice
// like any other feature. Exists so router.tsx's default route table
// compiles on a bare bootstrap.
export function NotFoundPage(): React.ReactElement {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold text-fg">Page not found</h1>
    </div>
  );
}

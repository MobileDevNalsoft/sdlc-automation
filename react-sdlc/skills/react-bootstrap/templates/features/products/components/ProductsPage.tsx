// DESTINATION: src/features/products/components/ProductsPage.tsx
//
// PLACEHOLDER — react-sdlc:react-slice replaces this with the real products
// feature. It exists only because router.tsx's default route table imports
// it by name; without a real file here, `tsc` fails with TS2307 on a bare
// bootstrap, before any feature has ever been sliced in.
export function ProductsPage(): React.ReactElement {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold text-fg">Products</h1>
    </div>
  );
}

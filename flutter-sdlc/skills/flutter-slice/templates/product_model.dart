// lib/features/product/domain/product_model.dart
//
// TEMPLATE — copy to lib/features/<feature>/domain/<feature>_model.dart and
// rename every `Product`/`product` identifier. There is no package name to
// substitute: this file has no imports, and that is the point.
//
// WHAT THIS IS
// The domain model: what the rest of the app (Cubit, Screen) actually depends
// on. It has ZERO imports — no json_annotation, no dio, no flutter. The data
// layer (ProductDto, in the sibling data/dto/ directory) is the only thing
// that knows this ever came from JSON at all, and the presentation layer is
// the only thing that knows it is ever drawn.
//
// The empty import list is a checkable invariant, not an aesthetic. If this
// file ever imports `package:dio` or `package:json_annotation`, the DTO/domain
// split has collapsed and a wire-format change will reach the UI.
//
// UNCHANGED by the move to dio, get_it, go_router, tokens and l10n. That is
// worth noticing: the layer that models the business is the layer that should
// survive every infrastructure decision above and below it.
//
// `Product` (id, name, price, createdAt) is a deliberately generic,
// obviously-illustrative placeholder entity — swap it and its fields for the
// real feature being sliced.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names and fields.
//   - Add `==`/`hashCode` (or extend `Equatable`) only once something
//     actually needs value equality — most commonly when this type ends up
//     inside a freezed state variant and a widget test asserts on two states
//     being equal. Kept minimal here rather than speculative.
//   - Keep it `const`-constructible. A const domain object is what lets a
//     test write a fixture inline with no setup.
//   - Do NOT put formatting here. `'\$${product.price}'` and
//     `DateFormat.yMMMd().format(createdAt)` are presentation concerns and
//     locale-dependent; they belong in the ARB via `context.l10n`, not on the
//     model. A `String get displayPrice` on this class is the most common
//     way a locale bug becomes unfixable.

/// A product, as the rest of the app understands one.
class ProductModel {
  /// Creates a product.
  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  /// Server-assigned identifier. Also the route's `:id` path parameter.
  final String id;

  /// Display name.
  final String name;

  /// Price, formatted for display by the ARB's ICU currency message — never
  /// by this class.
  final double price;

  /// When the product was created.
  final DateTime createdAt;
}

// lib/features/product/domain/product_model.dart
//
// Domain model: what the rest of the app (Cubit, Screen) actually depends on.
// Deliberately has zero import of json_annotation/json_serializable — the
// data layer (ProductDto, in the sibling data/dto/ directory) is the only
// thing that knows this ever came from JSON at all. Add `==`/`hashCode` (or
// switch to `Equatable`) only once something actually needs value equality —
// kept minimal here rather than speculative.
//
// `Product` is a deliberately generic, obviously-illustrative placeholder
// entity — swap it (and its fields) for the real feature being sliced.

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final DateTime createdAt;
}

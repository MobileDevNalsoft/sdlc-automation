// lib/features/product/data/dto/product_dto.dart
//
// TEMPLATE — copy to lib/features/<feature>/data/dto/<feature>_dto.dart,
// rename every `Product`/`product` identifier, replace the placeholder
// package name `my_app` in the import below with your own package name, and
// run `dart run build_runner build --delete-conflicting-outputs`. The
// `.g.dart` part file is generated, not hand-written (and is already excluded
// from analysis and coverage by flutter-bootstrap's analysis_options.yaml and
// build.yaml).
//
// WHAT THIS IS
// The DTO: the shape the backend actually sends. `field_rename: snake` is set
// once, project-wide, in flutter-bootstrap's build.yaml (delete it there if
// the target backend already returns lowerCamelCase JSON), so this class
// needs only the bare `@JsonSerializable()` annotation — `createdAt` maps to
// a backend `created_at` key with no per-field `@JsonKey` override.
//
// This is a deliberately separate class from `ProductModel` — the DTO's shape
// can change independently of what the rest of the app depends on, and
// `toDomain()` is the one place that mapping is allowed to happen. The split
// exists so whatever JSON casing convention the real backend uses never leaks
// past the data layer into anything a Cubit or a Screen touches.
// json_serializable@6.14.0 / json_annotation@4.12.0 (fetched from pub.dev's
// package API — see flutter-bootstrap's SKILL.md).
//
// UNCHANGED by the move to dio. The Service now hands this class a
// `Map<String, dynamic>` decoded by dio instead of by `jsonDecode`, which is
// the same input from this file's point of view.
//
// ---------------------------------------------------------------------------
// PARSE DEFENSIVELY — this closes a real hole in the error path
// ---------------------------------------------------------------------------
// A bad cast inside a generated `fromJson` (a JSON string where the DTO
// declares a `double`, a null where it declares a non-nullable `String`)
// throws `TypeError`. `TypeError` is an `Error`, NOT an `Exception`, so it is
// caught by neither `on DioException` nor `on FormatException` in the
// Repository — it escapes the Repository entirely and crashes the calling
// zone. The `Result<T>` seam does not protect you from it.
//
// The fix is HERE, not a wider catch there. `avoid_catching_errors` forbids
// `on TypeError`, and rightly: catching `Error` hides real programming bugs.
// Three defences, in order of preference:
//
//   1. Model the field as nullable when the backend can genuinely omit it,
//      and resolve the default in `toDomain()` — where a missing value
//      becomes a domain decision instead of a crash.
//   2. Use `@JsonKey(defaultValue: ...)` for fields the backend omits rather
//      than sends as null.
//   3. For fields whose type the backend is loose about (numbers arriving as
//      strings is the classic), give the field a `@JsonKey(fromJson: ...)`
//      converter that accepts both and returns your type. `num.tryParse`
//      returning null is a `FormatException` you can throw deliberately,
//      which the Repository DOES catch and maps to `SerializationError`.
//
// A DTO whose every field is non-nullable and strictly typed is a DTO that
// trusts the backend completely. That trust is fine for an API you own and
// version together; it is not fine for one you do not.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names and fields, matching the endpoint's real payload.
//   - Delete `toJson()` if nothing ever sends this shape back. It is
//     generated either way, but an unused public method is one more thing a
//     reader must check.
//   - Keep `toDomain()` total: no I/O, no `context`, no async. It is a pure
//     shape transform, which is what makes it trivially unit-testable.

import 'package:json_annotation/json_annotation.dart';
import 'package:my_app/features/product/domain/product_model.dart';

part 'product_dto.g.dart';

/// The wire shape of a product, exactly as the backend sends it.
///
/// Nothing above the data layer may reference this type — the Repository maps
/// it to [ProductModel] and hands that on.
@JsonSerializable()
class ProductDto {
  /// Creates a DTO. Normally built by [ProductDto.fromJson], not by hand.
  ProductDto({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  /// Decodes a DTO from a raw JSON map.
  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);

  /// Server-assigned identifier.
  final String id;

  /// Display name.
  final String name;

  /// Price, in the currency the backend documents for this endpoint.
  final double price;

  /// Creation timestamp. Maps from a `created_at` key via `field_rename`.
  final DateTime createdAt;

  /// Encodes this DTO back to a raw JSON map.
  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);

  /// The ONE place DTO -> domain mapping happens.
  ///
  /// Keeps [ProductModel] free of any json_serializable/json_annotation
  /// dependency, which is what lets the wire format change without the rest
  /// of the app noticing.
  ProductModel toDomain() =>
      ProductModel(id: id, name: name, price: price, createdAt: createdAt);
}

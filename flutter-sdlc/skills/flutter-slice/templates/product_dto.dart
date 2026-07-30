// lib/features/product/data/dto/product_dto.dart
//
// DTO: the shape the backend actually sends. field_rename: snake is set once,
// project-wide, in flutter-bootstrap's build.yaml (delete it there if the
// target backend already returns lowerCamelCase JSON) — so this class only
// needs the bare `@JsonSerializable()` annotation; `createdAt` below would map
// to a backend `created_at` key automatically, no per-field `@JsonKey` needed.
//
// This is a deliberately separate class from ProductModel (../../domain/
// product_model.dart) — the DTO's shape can change independently of what the
// rest of the app depends on, and `toDomain()` below is the one place that
// mapping is allowed to happen. json_serializable@6.14.0 / json_annotation@4.12.0
// (fetched from pub.dev's package API — see flutter-bootstrap's SKILL.md).

import 'package:json_annotation/json_annotation.dart';

import '../../domain/product_model.dart';

part 'product_dto.g.dart';

@JsonSerializable()
class ProductDto {
  ProductDto({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);

  final String id;
  final String name;
  final double price;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);

  /// The only place DTO -> domain mapping happens. Keeps ProductModel free of
  /// any json_serializable/json_annotation dependency.
  ProductModel toDomain() =>
      ProductModel(id: id, name: name, price: price, createdAt: createdAt);
}

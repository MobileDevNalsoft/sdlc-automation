// lib/features/product/data/services/product_service.dart
//
// Service layer: the ONLY layer allowed to know about HTTP. Talks to the
// backend's raw JSON shape directly and hands back a decoded map — it does
// NOT decide success/failure semantics or map to a domain model; that's the
// Repository's job (see product_repository.dart). A Service throwing on a
// network/HTTP-status failure is expected — the Repository is what turns
// that exception into a Result<T>, so exceptions never leak past that
// boundary into a Cubit.
//
// `Product` here is a deliberately generic, obviously-illustrative
// placeholder entity — swap `Product`/`product` for the real feature name
// and its real fields. The shape that stays constant across features:
// constructor takes baseUrl + optional injected http.Client, one method per
// endpoint, throws a feature-specific *ServiceException on a non-2xx
// response.

import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductService {
  ProductService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Returns the raw decoded JSON map for the given product id. Throws
  /// [ProductServiceException] on a non-2xx response; propagates whatever
  /// `http`/`dart:convert` throw on a network failure or malformed body —
  /// the Repository layer is responsible for catching all of it.
  Future<Map<String, dynamic>> fetchProduct(String id) async {
    final uri = Uri.parse('$baseUrl/products/$id');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProductServiceException(
        'GET $uri failed with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class ProductServiceException implements Exception {
  const ProductServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ProductServiceException($statusCode: $message)';
}

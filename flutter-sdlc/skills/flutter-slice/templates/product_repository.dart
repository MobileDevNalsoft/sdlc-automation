// lib/features/product/data/repositories/product_repository.dart
//
// Repository: the mandatory seam between Service (raw API calls, throws
// exceptions) and Cubit (Result<T>, never exceptions). Catches everything the
// Service/DTO layer can throw and normalizes it into Failure(AppError) so no
// try/catch ever needs to appear in a Cubit.
//
// This layer is mandatory for NEW features only — do not retrofit it onto
// existing code that already talks to a Service directly as a blanket
// requirement; that is a separate, deliberately-scoped migration decision,
// not something this template forces on adopted code.
//
// Every `catch` below has an `on` clause deliberately — very_good_analysis's
// vendored `avoid_catches_without_on_clauses` rule (see flutter-bootstrap's
// analysis_options.yaml) fails a bare `catch (e)`.

import '../../../../core/result.dart';
import '../../domain/product_model.dart';
import '../dto/product_dto.dart';
import '../services/product_service.dart';

abstract class ProductRepository {
  Future<Result<ProductModel>> getProduct(String id);
}

class ProductRepositoryImpl implements ProductRepository {
  const ProductRepositoryImpl(this._service);

  final ProductService _service;

  @override
  Future<Result<ProductModel>> getProduct(String id) async {
    try {
      final json = await _service.fetchProduct(id);
      final dto = ProductDto.fromJson(json);
      return Success(dto.toDomain());
    } on ProductServiceException catch (e) {
      return Failure(AppError(e.message, statusCode: e.statusCode));
    } on FormatException catch (e) {
      return Failure(AppError('Malformed product response: ${e.message}'));
    } on Exception catch (e) {
      return Failure(AppError('Unexpected error loading product: $e'));
    }
  }
}

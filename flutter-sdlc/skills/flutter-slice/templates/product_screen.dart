// lib/features/product/presentation/screens/product_screen.dart
//
// Exhaustive switch over ProductState — deliberately no `default:` case.
// ProductState being `sealed` (freezed@3.2.5) means Dart's own exhaustiveness
// checking makes forgetting a state variant a compile-time error, not a
// silent runtime gap; the vendored `no_default_cases` lint rule (see
// flutter-bootstrap's analysis_options.yaml) is the second line of defense
// in case a `default:` case sneaks back in during a refactor.
//
// flutter_bloc@9.1.1.
//
// This template only decides *which state produces which widget subtree* —
// it makes no visual-design decisions (typography, spacing, color, motion,
// platform conventions). Those belong to a separate UI/UX skill pairing
// (`sdlc-core:ui-ux-mobile` for design decisions, `sdlc-core:ui-ux-review`
// for auditing them) that this skill defers to entirely; see flutter-slice's
// SKILL.md "Screen: exhaustive switch, no default case" section.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/product_model.dart';
import '../bloc/product_cubit.dart';
import '../bloc/product_state.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: BlocBuilder<ProductCubit, ProductState>(
        builder: (context, state) => switch (state) {
          ProductInitial() => const _InitialView(),
          ProductLoading() => const Center(child: CircularProgressIndicator()),
          ProductLoaded(:final product) => _LoadedView(product: product),
          ProductError(:final message) => _ErrorView(message: message),
        },
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('${product.name} — \$${product.price}'));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Error: $message'));
  }
}

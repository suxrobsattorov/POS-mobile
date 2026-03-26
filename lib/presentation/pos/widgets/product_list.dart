import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/product_model.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';

class ProductList extends StatelessWidget {
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state.filteredProducts.isEmpty) {
          return Center(
            child: Text('Mahsulot topilmadi', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: state.filteredProducts.length,
          itemBuilder: (context, i) => _MobileProductCard(product: state.filteredProducts[i]),
        );
      },
    );
  }
}

class _MobileProductCard extends StatelessWidget {
  final ProductModel product;
  const _MobileProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity <= 0;
    return GestureDetector(
      onTap: outOfStock ? null : () => context.read<PosBloc>().add(ProductAddedToCart(product)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outOfStock ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.imageUrl != null
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                    if (outOfStock)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const Text('TUGAGAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    if (product.isLowStock && !outOfStock)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(4)),
                          child: Text('Kam', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _fmt(product.sellPrice),
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (!outOfStock)
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surfaceVariant,
    alignment: Alignment.center,
    child: Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textSecondary),
  );

  String _fmt(double v) =>
    v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

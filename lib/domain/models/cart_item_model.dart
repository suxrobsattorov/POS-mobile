import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  double quantity;
  double discountPercent;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.discountPercent = 0,
  });

  double get unitPrice => product.sellPrice;

  double get discountedPrice =>
      unitPrice * (1 - discountPercent / 100);

  double get subtotal => discountedPrice * quantity;

  CartItemModel copyWith({
    double? quantity,
    double? discountPercent,
  }) {
    return CartItemModel(
      product: product,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}

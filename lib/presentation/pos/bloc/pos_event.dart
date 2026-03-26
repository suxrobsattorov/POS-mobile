import '../../../domain/models/product_model.dart';
import '../../../domain/models/customer_model.dart';

abstract class PosEvent {}

class PosInitialized extends PosEvent {}

class ProductSearchChanged extends PosEvent {
  final String query;
  ProductSearchChanged(this.query);
}

class CategorySelected extends PosEvent {
  final int? categoryId;
  CategorySelected(this.categoryId);
}

class ProductAddedToCart extends PosEvent {
  final ProductModel product;
  ProductAddedToCart(this.product);
}

class CartItemQuantityChanged extends PosEvent {
  final int productId;
  final double quantity;
  CartItemQuantityChanged(this.productId, this.quantity);
}

class CartItemRemoved extends PosEvent {
  final int productId;
  CartItemRemoved(this.productId);
}

class CartCleared extends PosEvent {}

class CustomerSelected extends PosEvent {
  final CustomerModel? customer;
  CustomerSelected(this.customer);
}

/// Telefon raqami bo'yicha mijoz qidirish
class CustomerSearchByPhone extends PosEvent {
  final String phone;
  CustomerSearchByPhone(this.phone);
}

class BarcodeScanned extends PosEvent {
  final String barcode;
  BarcodeScanned(this.barcode);
}

class SaleSubmitted extends PosEvent {
  final List<SalePaymentEntry> payments;
  SaleSubmitted(this.payments);
}

class SalePaymentEntry {
  final int paymentMethodId;
  final double amount;
  SalePaymentEntry(this.paymentMethodId, this.amount);
}

class DiscountApplied extends PosEvent {
  final double percent;
  DiscountApplied(this.percent);
}

class SyncRequested extends PosEvent {}

class ShiftStatusUpdated extends PosEvent {
  final bool isOpen;
  ShiftStatusUpdated(this.isOpen);
}

import '../../../domain/models/product_model.dart';
import '../../../domain/models/cart_item_model.dart';
import '../../../domain/models/category_model.dart';
import '../../../domain/models/payment_method_model.dart';
import '../../../domain/models/customer_model.dart';

enum PosStatus {
  initial,
  loading,
  ready,
  processingPayment,
  success,
  error,
}

class PosState {
  final PosStatus status;
  final List<ProductModel> allProducts;
  final List<ProductModel> filteredProducts;
  final List<CategoryModel> categories;
  final List<PaymentMethodModel> paymentMethods;
  final List<CartItemModel> cartItems;
  final CustomerModel? selectedCustomer;
  final int? selectedCategoryId;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;
  final double discountPercent;
  final int pendingSalesCount;
  final bool isOnline;
  final int currentTabIndex;
  final bool isCustomerSearching;
  final bool isShiftOpen;
  final bool isSyncing;

  const PosState({
    this.status = PosStatus.initial,
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.categories = const [],
    this.paymentMethods = const [],
    this.cartItems = const [],
    this.selectedCustomer,
    this.selectedCategoryId,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
    this.discountPercent = 0,
    this.pendingSalesCount = 0,
    this.isOnline = true,
    this.currentTabIndex = 0,
    this.isCustomerSearching = false,
    this.isShiftOpen = false,
    this.isSyncing = false,
  });

  double get subtotal =>
      cartItems.fold(0.0, (s, i) => s + i.subtotal);
  double get discountAmount => subtotal * discountPercent / 100;
  double get netAmount => subtotal - discountAmount;
  int get cartItemCount =>
      cartItems.fold(0, (s, i) => s + i.quantity.toInt());
  bool get hasItems => cartItems.isNotEmpty;

  PosState copyWith({
    PosStatus? status,
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<CategoryModel>? categories,
    List<PaymentMethodModel>? paymentMethods,
    List<CartItemModel>? cartItems,
    CustomerModel? selectedCustomer,
    bool clearCustomer = false,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    double? discountPercent,
    int? pendingSalesCount,
    bool? isOnline,
    int? currentTabIndex,
    bool? isCustomerSearching,
    bool? isShiftOpen,
    bool? isSyncing,
  }) {
    return PosState(
      status: status ?? this.status,
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      cartItems: cartItems ?? this.cartItems,
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      successMessage: successMessage,
      discountPercent: discountPercent ?? this.discountPercent,
      pendingSalesCount: pendingSalesCount ?? this.pendingSalesCount,
      isOnline: isOnline ?? this.isOnline,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isCustomerSearching:
          isCustomerSearching ?? this.isCustomerSearching,
      isShiftOpen: isShiftOpen ?? this.isShiftOpen,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

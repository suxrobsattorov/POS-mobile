import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/network_info.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/remote/customer_repository.dart';
import '../../../data/remote/sale_repository.dart';
import '../../../data/remote/shift_service.dart';
import '../../../data/remote/sync_service.dart';
import '../../../domain/models/cart_item_model.dart';
import '../../../domain/models/sale_model.dart' as sale_model;
import 'pos_event.dart';
import 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final HiveService _hiveService;
  final SaleRepository _saleRepository;
  final CustomerRepository? _customerRepository;
  final SyncService _syncService;
  final ShiftService? _shiftService;
  StreamSubscription<bool>? _connectivitySub;

  PosBloc({
    required HiveService hiveService,
    required SaleRepository saleRepository,
    required SyncService syncService,
    CustomerRepository? customerRepository,
    ShiftService? shiftService,
  })  : _hiveService = hiveService,
        _saleRepository = saleRepository,
        _syncService = syncService,
        _customerRepository = customerRepository,
        _shiftService = shiftService,
        super(const PosState()) {
    on<PosInitialized>(_onInitialized);
    on<ProductSearchChanged>(_onSearch);
    on<CategorySelected>(_onCategory);
    on<ProductAddedToCart>(_onAddProduct);
    on<CartItemQuantityChanged>(_onQuantity);
    on<CartItemRemoved>(_onRemove);
    on<CartCleared>(_onClear);
    on<CustomerSelected>(_onCustomer);
    on<CustomerSearchByPhone>(_onCustomerSearchByPhone);
    on<BarcodeScanned>(_onBarcode);
    on<SaleSubmitted>(_onSale);
    on<DiscountApplied>(_onDiscount);
    on<SyncRequested>(_onSyncRequested);
    on<ShiftStatusUpdated>(_onShiftStatusUpdated);
    on<_ConnChange>(_onConn);
  }

  Future<void> _onInitialized(
      PosInitialized event, Emitter<PosState> emit) async {
    final products = _hiveService.getProducts();
    emit(state.copyWith(
      status: PosStatus.ready,
      allProducts: products,
      filteredProducts: products,
      categories: _hiveService.getCategories(),
      paymentMethods: _hiveService.getPaymentMethods(),
      pendingSalesCount: _hiveService.pendingSalesCount,
    ));
    _connectivitySub =
        NetworkInfo.connectivityStream.listen((v) => add(_ConnChange(v)));
    // Smena holatini serverdan tekshirish
    final shiftSvc = _shiftService;
    if (shiftSvc != null) {
      try {
        await shiftSvc.checkCurrentShift();
        if (!isClosed) {
          emit(state.copyWith(isShiftOpen: shiftSvc.isOpen));
        }
      } catch (_) {}
    }
  }

  void _onShiftStatusUpdated(
      ShiftStatusUpdated event, Emitter<PosState> emit) {
    emit(state.copyWith(isShiftOpen: event.isOpen));
  }

  void _onConn(_ConnChange event, Emitter<PosState> emit) {
    emit(state.copyWith(isOnline: event.v));
    // Internet qayta tiklanganda pending salesni yuklash
    if (event.v) {
      _syncService.forceSyncPendingSales().then((_) {
        if (!isClosed) {
          emit(state.copyWith(
              pendingSalesCount: _hiveService.pendingSalesCount));
        }
      });
    }
  }

  void _onSearch(ProductSearchChanged event, Emitter<PosState> emit) {
    final q = event.query.toLowerCase();
    final filtered = state.allProducts.where((p) =>
        (q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.barcode?.contains(q) ?? false)) &&
        (state.selectedCategoryId == null ||
            p.categoryId == state.selectedCategoryId)).toList();
    emit(state.copyWith(searchQuery: event.query, filteredProducts: filtered));
  }

  void _onCategory(CategorySelected event, Emitter<PosState> emit) {
    final id = event.categoryId;
    final filtered = state.allProducts.where((p) =>
        (state.searchQuery.isEmpty ||
            p.name
                .toLowerCase()
                .contains(state.searchQuery.toLowerCase())) &&
        (id == null || p.categoryId == id)).toList();
    if (id == null) {
      emit(state.copyWith(clearCategory: true, filteredProducts: filtered));
    } else {
      emit(state.copyWith(
          selectedCategoryId: id, filteredProducts: filtered));
    }
  }

  void _onAddProduct(ProductAddedToCart event, Emitter<PosState> emit) {
    final idx = state.cartItems
        .indexWhere((i) => i.product.id == event.product.id);
    List<CartItemModel> updated;
    if (idx >= 0) {
      updated = List.from(state.cartItems);
      updated[idx] = CartItemModel(
          product: updated[idx].product,
          quantity: updated[idx].quantity + 1);
    } else {
      updated = [
        ...state.cartItems,
        CartItemModel(product: event.product, quantity: 1)
      ];
    }
    emit(state.copyWith(cartItems: updated));
  }

  void _onQuantity(
      CartItemQuantityChanged event, Emitter<PosState> emit) {
    if (event.quantity <= 0) {
      add(CartItemRemoved(event.productId));
      return;
    }
    final updated = state.cartItems
        .map((i) => i.product.id == event.productId
            ? i.copyWith(quantity: event.quantity)
            : i)
        .toList();
    emit(state.copyWith(cartItems: updated));
  }

  void _onRemove(CartItemRemoved event, Emitter<PosState> emit) {
    emit(state.copyWith(
        cartItems: state.cartItems
            .where((i) => i.product.id != event.productId)
            .toList()));
  }

  void _onClear(CartCleared event, Emitter<PosState> emit) {
    emit(state.copyWith(
        cartItems: [], clearCustomer: true, discountPercent: 0));
  }

  void _onCustomer(CustomerSelected event, Emitter<PosState> emit) {
    if (event.customer == null) {
      emit(state.copyWith(clearCustomer: true, discountPercent: 0));
    } else {
      emit(state.copyWith(
          selectedCustomer: event.customer,
          discountPercent: event.customer!.discountPercent));
    }
  }

  Future<void> _onCustomerSearchByPhone(
      CustomerSearchByPhone event, Emitter<PosState> emit) async {
    if (_customerRepository == null) return;
    emit(state.copyWith(isCustomerSearching: true));
    try {
      final customer =
          await _customerRepository.getByPhone(event.phone);
      if (customer != null) {
        emit(state.copyWith(
          isCustomerSearching: false,
          selectedCustomer: customer,
          discountPercent: customer.discountPercent,
          successMessage: '${customer.name} tanlandi',
        ));
      } else {
        emit(state.copyWith(
          isCustomerSearching: false,
          errorMessage: 'Mijoz topilmadi',
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        isCustomerSearching: false,
        errorMessage: 'Qidiruvda xatolik',
      ));
    }
  }

  void _onBarcode(BarcodeScanned event, Emitter<PosState> emit) {
    try {
      final product = _hiveService.getProductByBarcode(event.barcode);
      add(ProductAddedToCart(product));
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Barcode topilmadi: ${event.barcode}'));
    }
  }

  Future<void> _onSale(
      SaleSubmitted event, Emitter<PosState> emit) async {
    emit(state.copyWith(status: PosStatus.processingPayment));
    final request = sale_model.CreateSaleRequest(
      customerId: state.selectedCustomer?.id,
      items: state.cartItems
          .map((i) => sale_model.SaleItemRequest(
                productId: i.product.id,
                quantity: i.quantity.toInt(),
                unitPrice: i.product.sellPrice,
                discountPercent: i.discountPercent,
              ))
          .toList(),
      payments: event.payments
          .map((p) => sale_model.PaymentRequest(
                paymentMethodId: p.paymentMethodId,
                amount: p.amount,
              ))
          .toList(),
    );

    final isOnline = await NetworkInfo.isConnected();
    if (isOnline) {
      try {
        final saleResp = await _saleRepository.createSale(request);
        emit(state.copyWith(
          status: PosStatus.success,
          successMessage: 'Sotuv #${saleResp.saleNumber} amalga oshirildi!',
          cartItems: [],
          clearCustomer: true,
          discountPercent: 0,
          pendingSalesCount: _hiveService.pendingSalesCount,
        ));
      } catch (_) {
        await _saveOffline(request);
        emit(state.copyWith(
          status: PosStatus.success,
          successMessage: 'Oflayn saqlandi',
          cartItems: [],
          clearCustomer: true,
          discountPercent: 0,
          pendingSalesCount: _hiveService.pendingSalesCount,
        ));
      }
    } else {
      await _saveOffline(request);
      emit(state.copyWith(
        status: PosStatus.success,
        successMessage: 'Oflayn rejimda saqlandi',
        cartItems: [],
        clearCustomer: true,
        discountPercent: 0,
        pendingSalesCount: _hiveService.pendingSalesCount,
      ));
    }
  }

  Future<void> _saveOffline(
      sale_model.CreateSaleRequest request) async {
    await _hiveService.savePendingSale(sale_model.PendingSale(
      localId: DateTime.now().millisecondsSinceEpoch.toString(),
      saleData: request.toJson(),
      createdAt: DateTime.now(),
    ));
  }

  void _onDiscount(DiscountApplied event, Emitter<PosState> emit) {
    emit(state.copyWith(discountPercent: event.percent));
  }

  Future<void> _onSyncRequested(
      SyncRequested event, Emitter<PosState> emit) async {
    emit(state.copyWith(isSyncing: true));
    try {
      await _syncService.syncAll();
      final products = _hiveService.getProducts();
      emit(state.copyWith(
        isSyncing: false,
        allProducts: products,
        filteredProducts: products,
        categories: _hiveService.getCategories(),
        paymentMethods: _hiveService.getPaymentMethods(),
        successMessage: 'Sinxronlash tugadi',
      ));
    } catch (_) {
      emit(state.copyWith(
        isSyncing: false,
        errorMessage: 'Sinxronlashda xatolik',
      ));
    }
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }
}

class _ConnChange extends PosEvent {
  final bool v;
  _ConnChange(this.v);
}

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../data/local/hive_service.dart';
import '../../domain/models/product_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/payment_method_model.dart';

class ProductRepository {
  final ApiClient _apiClient;
  final HiveService? _hiveService;

  ProductRepository(this._apiClient, {HiveService? hiveService})
      : _hiveService = hiveService;

  // ── Remote ─────────────────────────────────────────────────────────────────

  /// GET /api/v1/products (barcha aktiv mahsulotlar)
  Future<List<ProductModel>> fetchAllFromServer() async {
    final response = await _apiClient.dio.get(
      ApiConfig.products,
      queryParameters: {'page': 0, 'size': 10000, 'active': true},
    );
    final List data = response.data is List
        ? response.data
        : (response.data['content'] ?? []);
    return data
        .map((j) => ProductModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /api/v1/products/barcode-lookup?barcode={barcode}
  Future<ProductModel?> findByBarcode(String barcode) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.products}/barcode-lookup',
        queryParameters: {'barcode': barcode},
      );
      return ProductModel.fromJson(
          Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/products/all-active
  Future<List<ProductModel>> getAllActive() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.products}/all-active',
      );
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) => ProductModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return fetchAllFromServer();
    }
  }

  /// GET /api/v1/products/barcode/{barcode}
  Future<ProductModel?> getByBarcode(String barcode) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.barcode}/$barcode',
      );
      return ProductModel.fromJson(
          Map<String, dynamic>.from(response.data));
    } catch (_) {
      return findByBarcode(barcode);
    }
  }

  // ── Local (Hive) ────────────────────────────────────────────────────────────

  /// Hive'dan barcha mahsulotlar
  List<ProductModel> getAllLocal() {
    return _hiveService?.getProducts() ?? [];
  }

  /// Barcode bo'yicha lokal qidirish
  ProductModel? findByBarcodeLocal(String barcode) {
    try {
      return _hiveService?.getProductByBarcode(barcode);
    } catch (_) {
      return null;
    }
  }

  // ── Sync ────────────────────────────────────────────────────────────────────

  /// Mahsulotlarni serverdan yuklab Hive'ga saqlash
  Future<void> syncProducts() async {
    if (_hiveService == null) return;
    final products = await fetchAllFromServer();
    await _hiveService.saveProducts(products);
  }

  /// Kategoriyalarni serverdan yuklab Hive'ga saqlash
  Future<void> syncCategories() async {
    if (_hiveService == null) return;
    final response = await _apiClient.dio.get(ApiConfig.categories);
    final List data = response.data is List
        ? response.data
        : (response.data['content'] ?? []);
    final categories = data
        .map((j) => CategoryModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    await _hiveService.saveCategories(categories);
  }

  /// To'lov usullarini serverdan yuklab Hive'ga saqlash
  Future<void> syncPaymentMethods() async {
    if (_hiveService == null) return;
    final response = await _apiClient.dio.get(ApiConfig.paymentMethods);
    final List data = response.data is List
        ? response.data
        : (response.data['content'] ?? []);
    final methods = data
        .map((j) =>
            PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    await _hiveService.savePaymentMethods(methods);
  }
}

import 'dart:async';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_info.dart';
import '../../data/local/hive_service.dart';
import '../../domain/models/product_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/payment_method_model.dart';
import '../../domain/models/customer_model.dart';

class SyncService {
  final ApiClient _apiClient;
  final HiveService _hiveService;
  Timer? _syncTimer;

  SyncService(this._apiClient, this._hiveService);

  /// Called after login — syncs all reference data to Hive
  Future<void> syncAll() async {
    await Future.wait([
      _syncProducts(),
      _syncCategories(),
      _syncPaymentMethods(),
      _syncCustomers(),
      _syncSettings(),
    ]);
  }

  Future<void> _syncProducts() async {
    final response =
        await _apiClient.dio.get(ApiConfig.products, queryParameters: {
      'page': 0,
      'size': 10000,
      'active': true,
    });
    final List data = response.data['content'] ?? response.data;
    final products = data
        .map((j) => ProductModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    await _hiveService.saveProducts(products);
  }

  Future<void> _syncCategories() async {
    final response = await _apiClient.dio.get(ApiConfig.categories);
    final List data = response.data;
    final categories = data
        .map((j) => CategoryModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    await _hiveService.saveCategories(categories);
  }

  Future<void> _syncPaymentMethods() async {
    final response = await _apiClient.dio.get(ApiConfig.paymentMethods);
    final List data = response.data;
    final methods = data
        .map((j) =>
            PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    await _hiveService.savePaymentMethods(methods);
  }

  Future<void> _syncCustomers() async {
    try {
      final response = await _apiClient.dio
          .get(ApiConfig.customers, queryParameters: {'size': 10000});
      final List data = response.data['content'] ?? response.data;
      final customers = data
          .map((j) => CustomerModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      await _hiveService.saveCustomers(customers);
    } catch (_) {}
  }

  Future<void> _syncSettings() async {
    try {
      final response = await _apiClient.dio.get(ApiConfig.settings);
      final List data = response.data;
      final map = <String, String>{};
      for (final item in data) {
        map[item['key'].toString()] = item['value']?.toString() ?? '';
      }
      await _hiveService.saveSettings(map);
    } catch (_) {}
  }

  /// Start background sync — uploads pending sales every 30 seconds
  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final isOnline = await NetworkInfo.isConnected();
      if (isOnline) {
        await _uploadPendingSales();
      }
    });
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _uploadPendingSales() async {
    final pending = _hiveService.getPendingSales();
    for (final sale in pending) {
      try {
        await _apiClient.dio.post(ApiConfig.sales, data: sale.saleData);
        await _hiveService.markSaleSynced(sale.localId);
      } catch (_) {
        // Will retry next cycle
      }
    }
  }

  Future<void> forceSyncPendingSales() async {
    final isOnline = await NetworkInfo.isConnected();
    if (isOnline) {
      await _uploadPendingSales();
    }
  }
}

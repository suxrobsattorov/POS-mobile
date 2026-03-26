import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/payment_method_model.dart';

class PaymentMethodRepository {
  final ApiClient _apiClient;
  PaymentMethodRepository(this._apiClient);

  /// GET /api/v1/payment-methods — barcha to'lov usullari
  Future<List<PaymentMethodModel>> getAll() async {
    final response = await _apiClient.dio.get(ApiConfig.paymentMethods);
    final List data = response.data is List
        ? response.data
        : (response.data['content'] ?? []);
    return data
        .map((j) =>
            PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /api/v1/payment-methods/active — faqat aktiv to'lov usullari
  Future<List<PaymentMethodModel>> getActive() async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.paymentMethods}/active',
      );
      final List data = response.data is List
          ? response.data
          : (response.data['content'] ?? []);
      return data
          .map((j) =>
              PaymentMethodModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      // Fallback: barcha usullarni qaytarish
      return getAll();
    }
  }
}

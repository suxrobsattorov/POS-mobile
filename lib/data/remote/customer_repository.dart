import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/customer_model.dart';

class CustomerRepository {
  final ApiClient _apiClient;
  CustomerRepository(this._apiClient);

  /// GET /api/v1/customers/phone/{phone} — telefon bo'yicha qidirish
  Future<CustomerModel?> getByPhone(String phone) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.customers}/phone/$phone',
      );
      return CustomerModel.fromJson(
          Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/customers — barcha mijozlar (paginatsiyali)
  Future<List<CustomerModel>> getAll({int size = 10000}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConfig.customers,
        queryParameters: {'size': size},
      );
      final List data = response.data['content'] ?? response.data;
      return data
          .map((j) =>
              CustomerModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

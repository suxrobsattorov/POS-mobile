import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/sale_model.dart';

class SaleHistoryItem {
  final int id;
  final String saleNumber;
  final double netAmount;
  final int itemCount;
  final String paymentType;
  final String cashierName;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;

  const SaleHistoryItem({
    required this.id,
    required this.saleNumber,
    required this.netAmount,
    required this.itemCount,
    required this.paymentType,
    required this.cashierName,
    required this.createdAt,
    this.items = const [],
    this.payments = const [],
  });

  factory SaleHistoryItem.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((i) => Map<String, dynamic>.from(i))
        .toList();
    final paymentsList = (json['payments'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    String payType = 'Noma\'lum';
    if (paymentsList.length > 1) {
      payType = 'Aralash';
    } else if (paymentsList.isNotEmpty) {
      payType = paymentsList.first['paymentMethodName']?.toString() ?? 'Noma\'lum';
    }
    return SaleHistoryItem(
      id: json['id'] ?? 0,
      saleNumber: json['saleNumber'] ?? '',
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      itemCount: itemsList.length,
      paymentType: payType,
      cashierName: json['cashierName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      items: itemsList,
      payments: paymentsList,
    );
  }
}

class SaleRepository {
  final ApiClient _apiClient;
  SaleRepository(this._apiClient);

  Future<SaleResponse> createSale(CreateSaleRequest request) async {
    final response =
        await _apiClient.dio.post(ApiConfig.sales, data: request.toJson());
    return SaleResponse.fromJson(response.data);
  }

  /// GET /api/v1/sales?startDate=&endDate=&page=&size=
  Future<Map<String, dynamic>> getSalesHistory({
    DateTime? startDate,
    DateTime? endDate,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (startDate != null) {
      params['startDate'] = startDate.toIso8601String().split('T').first;
    }
    if (endDate != null) {
      params['endDate'] = endDate.toIso8601String().split('T').first;
    }
    final response = await _apiClient.dio.get(
      ApiConfig.sales,
      queryParameters: params,
    );
    final data = response.data;
    if (data is Map && data.containsKey('content')) {
      final items = (data['content'] as List)
          .map((j) => SaleHistoryItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      return {
        'items': items,
        'totalPages': data['totalPages'] ?? 1,
        'totalElements': data['totalElements'] ?? items.length,
        'last': data['last'] ?? true,
      };
    }
    // Agar pagination yo'q, oddiy list
    final items = (data as List)
        .map((j) => SaleHistoryItem.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    return {'items': items, 'totalPages': 1, 'totalElements': items.length, 'last': true};
  }
}

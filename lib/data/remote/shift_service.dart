import '../../core/network/api_client.dart';

class ShiftStats {
  final int saleCount;
  final double totalAmount;
  final DateTime openedAt;
  final int shiftId;

  const ShiftStats({
    required this.saleCount,
    required this.totalAmount,
    required this.openedAt,
    required this.shiftId,
  });

  factory ShiftStats.fromJson(Map<String, dynamic> json) => ShiftStats(
        shiftId: json['id'] ?? 0,
        saleCount: json['saleCount'] ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        openedAt: json['openedAt'] != null
            ? DateTime.tryParse(json['openedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class ShiftService {
  final ApiClient _apiClient;
  ShiftStats? _currentShift;

  ShiftService(this._apiClient);

  bool get isOpen => _currentShift != null;
  ShiftStats? get currentShift => _currentShift;

  /// GET /api/v1/shifts/current — joriy smenani tekshirish
  Future<void> checkCurrentShift() async {
    try {
      final response = await _apiClient.dio.get('/shifts/current');
      if (response.data != null && response.data['id'] != null) {
        _currentShift = ShiftStats.fromJson(
            Map<String, dynamic>.from(response.data));
      } else {
        _currentShift = null;
      }
    } catch (_) {
      _currentShift = null;
    }
  }

  /// POST /api/v1/shifts/open — smena ochish
  Future<void> openShift({required double openingBalance}) async {
    final response = await _apiClient.dio.post(
      '/shifts/open',
      data: {'openingBalance': openingBalance},
    );
    _currentShift =
        ShiftStats.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// POST /api/v1/shifts/close — smena yopish
  Future<void> closeShift() async {
    if (_currentShift == null) return;
    await _apiClient.dio.post(
      '/shifts/${_currentShift!.shiftId}/close',
    );
    _currentShift = null;
  }
}

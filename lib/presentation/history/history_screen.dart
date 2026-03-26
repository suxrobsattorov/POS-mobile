import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/sale_repository.dart';
import '../../core/network/network_info.dart';
import '../../domain/models/sale_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _saleRepo = sl<SaleRepository>();
  final _hive = sl<HiveService>();

  // Filter holati
  DateTime? _startDate;
  DateTime? _endDate;
  _DateFilter _quickFilter = _DateFilter.today;

  // Server ma'lumotlari
  final List<SaleHistoryItem> _serverItems = [];
  int _currentPage = 0;
  bool _isLastPage = false;
  bool _isLoadingMore = false;
  bool _isOnline = false;

  // Offline (Hive) ma'lumotlari
  List<PendingSale> _pendingItems = [];

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _checkConnection();
    _loadOffline();
    _loadServerItems(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreIfNeeded();
    }
  }

  Future<void> _checkConnection() async {
    final online = await NetworkInfo.isConnected();
    if (mounted) setState(() => _isOnline = online);
  }

  void _loadOffline() {
    final all = _hive.getPendingSales();
    final now = DateTime.now();
    setState(() {
      _pendingItems = all.where((s) {
        final from = _effectiveStart(now);
        final to = _effectiveEnd(now);
        return s.createdAt.isAfter(from.subtract(const Duration(seconds: 1))) &&
            s.createdAt.isBefore(to.add(const Duration(days: 1)));
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _loadServerItems({bool reset = false}) async {
    if (!_isOnline) return;
    if (reset) {
      setState(() {
        _serverItems.clear();
        _currentPage = 0;
        _isLastPage = false;
      });
    }
    if (_isLastPage || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final now = DateTime.now();
      final result = await _saleRepo.getSalesHistory(
        startDate: _effectiveStart(now),
        endDate: _effectiveEnd(now),
        page: _currentPage,
        size: 20,
      );
      if (!mounted) return;
      final items = result['items'] as List<SaleHistoryItem>;
      setState(() {
        _serverItems.addAll(items);
        _isLastPage = result['last'] == true;
        _currentPage++;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (!_isLoadingMore && !_isLastPage && _isOnline) {
      await _loadServerItems();
    }
  }

  Future<void> _refresh() async {
    await _checkConnection();
    _loadOffline();
    if (_isOnline) {
      await _loadServerItems(reset: true);
    }
  }

  DateTime _effectiveStart(DateTime now) {
    if (_startDate != null) return _startDate!;
    switch (_quickFilter) {
      case _DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return DateTime(y.year, y.month, y.day);
      case _DateFilter.week:
        return now.subtract(const Duration(days: 7));
      case _DateFilter.custom:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _effectiveEnd(DateTime now) {
    if (_endDate != null) return _endDate!;
    switch (_quickFilter) {
      case _DateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return DateTime(y.year, y.month, y.day, 23, 59, 59);
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Sotuv tarixi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick filter chips
          _QuickFilterBar(
            selected: _quickFilter,
            onSelect: (f) {
              setState(() {
                _quickFilter = f;
                _startDate = null;
                _endDate = null;
              });
              _loadOffline();
              _loadServerItems(reset: true);
            },
          ),

          // Connectivity banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Oflayn rejim — faqat lokal sotuvlar ko\'rsatilmoqda',
                      style: TextStyle(
                          color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final combined = <_HistoryEntry>[];

    // Server ma'lumotlari
    for (final item in _serverItems) {
      combined.add(_HistoryEntry.fromServer(item));
    }

    // Pending (offline) sotuvlar — server topilmaganlari
    for (final pending in _pendingItems) {
      // Dublikat bo'lmasin deb server list ga qo'shimaymiz (offline bo'lsa)
      if (!_isOnline) {
        combined.add(_HistoryEntry.fromPending(pending));
      }
    }

    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (combined.isEmpty && !_isLoadingMore) {
      return _EmptyHistory(
        filterLabel: _isOnline ? _filterLabel(_quickFilter) : 'oflayn rejim',
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: combined.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == combined.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final entry = combined[i];
        return _SaleHistoryCard(
          entry: entry,
          onTap: () => _showDetailSheet(context, entry),
        );
      },
    );
  }

  String _filterLabel(_DateFilter f) {
    switch (f) {
      case _DateFilter.today:
        return 'bugun';
      case _DateFilter.yesterday:
        return 'kecha';
      case _DateFilter.week:
        return 'oxirgi 7 kun';
      case _DateFilter.custom:
        return 'tanlangan davr';
    }
  }

  void _showDetailSheet(BuildContext context, _HistoryEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _SaleDetailSheet(entry: entry),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    DateTime? tmpStart = _startDate;
    DateTime? tmpEnd = _endDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        initialStart: tmpStart,
        initialEnd: tmpEnd,
        onApply: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
            _quickFilter = _DateFilter.custom;
          });
          _loadOffline();
          _loadServerItems(reset: true);
        },
      ),
    );
  }
}

// ── History Entry ────────────────────────────────────────────────────

class _HistoryEntry {
  final String id;
  final String receiptNumber;
  final double total;
  final int itemCount;
  final String paymentType;
  final DateTime createdAt;
  final bool isOffline;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;

  const _HistoryEntry({
    required this.id,
    required this.receiptNumber,
    required this.total,
    required this.itemCount,
    required this.paymentType,
    required this.createdAt,
    required this.isOffline,
    this.items = const [],
    this.payments = const [],
  });

  factory _HistoryEntry.fromServer(SaleHistoryItem s) => _HistoryEntry(
        id: '${s.id}',
        receiptNumber: s.saleNumber,
        total: s.netAmount,
        itemCount: s.itemCount,
        paymentType: s.paymentType,
        createdAt: s.createdAt,
        isOffline: false,
        items: s.items,
        payments: s.payments,
      );

  factory _HistoryEntry.fromPending(PendingSale p) {
    final items = (p.saleData['items'] as List? ?? [])
        .map((i) => Map<String, dynamic>.from(i))
        .toList();
    final payments = (p.saleData['payments'] as List? ?? [])
        .map((i) => Map<String, dynamic>.from(i))
        .toList();
    double total = 0;
    for (final item in items) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      total += qty * price;
    }
    String payType = 'Noma\'lum';
    if (payments.length > 1) payType = 'Aralash';

    final ts = int.tryParse(p.localId);
    final saleNum = ts != null
        ? '#${DateTime.fromMillisecondsSinceEpoch(ts).year}'
            '${DateTime.fromMillisecondsSinceEpoch(ts).month.toString().padLeft(2, '0')}'
            '${DateTime.fromMillisecondsSinceEpoch(ts).day.toString().padLeft(2, '0')}'
            '-${p.localId.substring(p.localId.length - 4)}'
        : '#${p.localId}';

    return _HistoryEntry(
      id: p.localId,
      receiptNumber: saleNum,
      total: total,
      itemCount: items.length,
      paymentType: payType,
      createdAt: p.createdAt,
      isOffline: true,
      items: items,
      payments: payments,
    );
  }
}

// ── Quick Filter Bar ─────────────────────────────────────────────────

class _QuickFilterBar extends StatelessWidget {
  final _DateFilter selected;
  final ValueChanged<_DateFilter> onSelect;

  const _QuickFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _DateFilter.values.map((f) {
          final sel = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                _label(f),
                style: TextStyle(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      sel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(_DateFilter f) {
    switch (f) {
      case _DateFilter.today:
        return 'Bugun';
      case _DateFilter.yesterday:
        return 'Kecha';
      case _DateFilter.week:
        return '7 kun';
      case _DateFilter.custom:
        return 'Maxsus';
    }
  }
}

// ── Empty State ────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  final String filterLabel;
  const _EmptyHistory({required this.filterLabel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sotuv topilmadi',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '$filterLabel uchun sotuv yo\'q',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sale History Card ──────────────────────────────────────────────

class _SaleHistoryCard extends StatelessWidget {
  final _HistoryEntry entry;
  final VoidCallback onTap;

  const _SaleHistoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time =
        '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';
    final date =
        '${entry.createdAt.day.toString().padLeft(2, '0')}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.receiptNumber,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$date $time | ${entry.paymentType} | ${entry.itemCount} ta',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Amount + badge
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(entry.total)} UZS',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.isOffline
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: entry.isOffline
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : AppColors.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    entry.isOffline ? 'OFLAYN' : 'SINX',
                    style: TextStyle(
                      color: entry.isOffline
                          ? AppColors.warning
                          : AppColors.success,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');
}

// ── Sale Detail BottomSheet ────────────────────────────────────────

class _SaleDetailSheet extends StatelessWidget {
  final _HistoryEntry entry;

  const _SaleDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.receiptNumber,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(entry.createdAt),
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: entry.isOffline
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.isOffline ? 'OFLAYN' : 'SINXRONLANGAN',
                      style: TextStyle(
                        color: entry.isOffline
                            ? AppColors.warning
                            : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 20),

            // Body
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Items
                  _SectionLabel(label: 'Mahsulotlar'),
                  const SizedBox(height: 8),
                  if (entry.items.isEmpty)
                    const Text('Ma\'lumot yo\'q',
                        style:
                            TextStyle(color: AppColors.textSecondary))
                  else
                    ...entry.items.map((item) {
                      final name = item['productName']?.toString() ??
                          'Mahsulot #${item['productId']}';
                      final qty =
                          (item['quantity'] as num?)?.toInt() ?? 0;
                      final price =
                          (item['unitPrice'] as num?)?.toDouble() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13),
                              ),
                            ),
                            Text(
                              '$qty x ${_fmt(price)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmt(qty * price),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // To'lovlar
                  _SectionLabel(label: "To'lov usullari"),
                  const SizedBox(height: 8),
                  if (entry.payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.paymentType,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            '${_fmt(entry.total)} UZS',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    ...entry.payments.map((p) {
                      final method =
                          p['paymentMethodName']?.toString() ??
                              'Usul #${p['paymentMethodId']}';
                      final amount =
                          (p['amount'] as num?)?.toDouble() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(method,
                                style: const TextStyle(
                                    color: AppColors.textPrimary)),
                            Text(
                              '${_fmt(amount)} UZS',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),

                  // Total
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'JAMI:',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${_fmt(entry.total)} UZS',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Yopish tugmasi
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Yopish'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');
}

// ── Section Label ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Filter BottomSheet ─────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime? start, DateTime? end) onApply;

  const _FilterSheet({
    required this.onApply,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime? _start;
  late DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end != null && _end!.isBefore(_start!)) _end = _start;
        } else {
          _end = picked;
          if (_start != null && _start!.isAfter(_end!)) _start = _end;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Sana oraliqi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DatePickerButton(
                    label: 'Boshlanish',
                    date: _start,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '—',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: _DatePickerButton(
                    label: 'Tugash',
                    date: _end,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _start = null;
                        _end = null;
                      });
                      widget.onApply(null, null);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Tozalash'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_start, _end);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Filtrlash'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}'
                      : 'Tanlang',
                  style: TextStyle(
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _DateFilter { today, yesterday, week, custom }

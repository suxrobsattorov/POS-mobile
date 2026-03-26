import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/customer_repository.dart';
import '../../data/remote/sale_repository.dart';
import '../../data/remote/shift_service.dart';
import '../../data/remote/sync_service.dart';
import '../../domain/models/customer_model.dart';
import 'bloc/pos_bloc.dart';
import 'bloc/pos_event.dart';
import 'bloc/pos_state.dart';
import 'widgets/product_list.dart';
import '../payment/payment_screen.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PosBloc(
        hiveService: sl<HiveService>(),
        saleRepository: sl<SaleRepository>(),
        syncService: sl<SyncService>(),
        customerRepository: sl<CustomerRepository>(),
        shiftService: sl<ShiftService>(),
      )..add(PosInitialized()),
      child: const _PosBody(),
    );
  }
}

class _PosBody extends StatefulWidget {
  const _PosBody();
  @override
  State<_PosBody> createState() => _PosBodyState();
}

class _PosBodyState extends State<_PosBody> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          // To'lov muvaffaqiyatli bo'lsa savatga o'tamiz
          if (state.status == PosStatus.success && _selectedTab == 1) {
            setState(() => _selectedTab = 0);
          }
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: _selectedTab == 0
            ? const Column(children: [
                _SearchAndCategory(),
                Expanded(child: _ProductsWithEmpty()),
              ])
            : const _CartView(),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton:
            _selectedTab == 0 ? _ScanFab() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.point_of_sale_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              sl<HiveService>().getShopName(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          BlocBuilder<PosBloc, PosState>(
            buildWhen: (prev, curr) =>
                prev.isOnline != curr.isOnline ||
                prev.pendingSalesCount != curr.pendingSalesCount,
            builder: (context, state) {
              return Row(
                children: [
                  if (!state.isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Oflayn',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  if (state.pendingSalesCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${state.pendingSalesCount} kutmoqda',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        // Smena icon
        BlocBuilder<PosBloc, PosState>(
          buildWhen: (p, c) => p.isShiftOpen != c.isShiftOpen,
          builder: (context, state) {
            return IconButton(
              tooltip: state.isShiftOpen ? 'Smena ochiq' : 'Smena yopiq',
              icon: Icon(
                Icons.access_time_rounded,
                color: state.isShiftOpen
                    ? AppColors.success
                    : AppColors.error,
              ),
              onPressed: () => _showShiftBottomSheet(context),
            );
          },
        ),
        // Mijoz qidirish
        IconButton(
          tooltip: 'Mijoz qidirish',
          icon: const Icon(Icons.person_add_outlined,
              color: AppColors.textSecondary),
          onPressed: () => _showCustomerSearchDialog(context),
        ),
        // Tarix
        IconButton(
          tooltip: 'Sotuv tarixi',
          icon: const Icon(Icons.history_rounded,
              color: AppColors.textSecondary),
          onPressed: () => context.push('/history'),
        ),
        // Menu
        PopupMenuButton(
          icon: const Icon(Icons.more_vert,
              color: AppColors.textSecondary),
          color: AppColors.surface,
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary, size: 18),
                SizedBox(width: 8),
                Text('Sozlamalar',
                    style: TextStyle(color: AppColors.textPrimary)),
              ]),
              onTap: () => context.push('/settings'),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.access_time_rounded,
                    color: AppColors.textSecondary, size: 18),
                SizedBox(width: 8),
                Text('Smena',
                    style: TextStyle(color: AppColors.textPrimary)),
              ]),
              onTap: () => _showShiftBottomSheet(context),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.logout, color: AppColors.error, size: 18),
                SizedBox(width: 8),
                Text('Chiqish',
                    style: TextStyle(color: AppColors.error)),
              ]),
              onTap: () async {
                await sl<HiveService>().clearAuth();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) => p.cartItemCount != c.cartItemCount,
      builder: (context, state) {
        return BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Mahsulotlar',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (state.cartItemCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${state.cartItemCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Savat',
            ),
          ],
        );
      },
    );
  }

  void _showCustomerSearchDialog(BuildContext context) {
    final bloc = context.read<PosBloc>();
    showDialog(
      context: context,
      builder: (ctx) => _CustomerSearchDialog(bloc: bloc),
    );
  }

  Future<void> _showShiftBottomSheet(BuildContext context) async {
    final posBloc = context.read<PosBloc>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ShiftBottomSheet(),
    );
    // Result: true = ochildi, false = yopildi, null = bekor
    if (result != null) {
      posBloc.add(ShiftStatusUpdated(result));
    }
  }
}

// ── Products Tab + Empty State ──────────────────────────────────────

class _ProductsWithEmpty extends StatelessWidget {
  const _ProductsWithEmpty();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) =>
          p.filteredProducts.length != c.filteredProducts.length ||
          p.allProducts.length != c.allProducts.length ||
          p.isSyncing != c.isSyncing,
      builder: (context, state) {
        if (state.isSyncing) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.allProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 72,
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mahsulotlar yuklanmadi',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<PosBloc>().add(SyncRequested()),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sinxronlash'),
                ),
              ],
            ),
          );
        }
        return const ProductList();
      },
    );
  }
}

// ── Search + Category ──────────────────────────────────────────────

class _SearchAndCategory extends StatelessWidget {
  const _SearchAndCategory();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) =>
          p.categories != c.categories ||
          p.selectedCategoryId != c.selectedCategoryId ||
          p.selectedCustomer != c.selectedCustomer,
      builder: (context, state) {
        return Column(
          children: [
            // Customer chip
            if (state.selectedCustomer != null)
              Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 12, top: 8),
                child: _CustomerChip(
                    customer: state.selectedCustomer!),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Mahsulot qidirish...',
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (q) =>
                    context.read<PosBloc>().add(ProductSearchChanged(q)),
              ),
            ),
            if (state.categories.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _CategoryChip(
                      label: 'Barchasi',
                      selected: state.selectedCategoryId == null,
                      onTap: () => context
                          .read<PosBloc>()
                          .add(CategorySelected(null)),
                    ),
                    ...state.categories.map((cat) => _CategoryChip(
                          label: cat.name,
                          selected:
                              state.selectedCategoryId == cat.id,
                          onTap: () => context
                              .read<PosBloc>()
                              .add(CategorySelected(cat.id)),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _CustomerChip extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerChip({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                customer.name,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (customer.discountPercent > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${customer.discountPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context
                    .read<PosBloc>()
                    .add(CustomerSelected(null)),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Cart View ──────────────────────────────────────────────────────

class _CartView extends StatelessWidget {
  const _CartView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color:
                      AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Savat bo\'sh',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 18),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Customer + discount summary
            if (state.selectedCustomer != null)
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.selectedCustomer!.name,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (state.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${_fmt(state.discountAmount)} UZS chegirma',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: state.cartItems.length,
                itemBuilder: (context, index) {
                  final item = state.cartItems[index];
                  return Dismissible(
                    key: Key('cart_${item.product.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => context
                        .read<PosBloc>()
                        .add(CartItemRemoved(item.product.id)),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${_fmt(item.product.sellPrice)} UZS',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _QtyBtn(
                                  icon: Icons.remove,
                                  onTap: () => context
                                      .read<PosBloc>()
                                      .add(CartItemQuantityChanged(
                                          item.product.id,
                                          item.quantity - 1)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    '${item.quantity.toInt()}',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                _QtyBtn(
                                  icon: Icons.add,
                                  onTap: () => context
                                      .read<PosBloc>()
                                      .add(CartItemQuantityChanged(
                                          item.product.id,
                                          item.quantity + 1)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_fmt(item.subtotal)} UZS',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Summary + pay button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: AppColors.surface,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jami:',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                      Text('${_fmt(state.subtotal)} UZS',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (state.discountAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Chegirma:',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                        Text('-${_fmt(state.discountAmount)} UZS',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TO'LOV:",
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      Text(
                        '${_fmt(state.netAmount)} UZS',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: state.hasItems
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<PosBloc>(),
                                    child: const PaymentScreen(),
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.payment),
                      label: const Text(
                        "TO'LOV QILISH",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── Scanner FAB ────────────────────────────────────────────────────

class _ScanFab extends StatelessWidget {
  const _ScanFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      tooltip: 'Barkod skanerlash',
      child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      onPressed: () => _openScannerSheet(context),
    );
  }

  Future<void> _openScannerSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PosBloc>(),
        child: const _ScannerBottomSheet(),
      ),
    );
  }
}

// ── TASK-FM07: ScannerBottomSheet ──────────────────────────────────

class _ScannerBottomSheet extends StatefulWidget {
  const _ScannerBottomSheet();
  @override
  State<_ScannerBottomSheet> createState() =>
      _ScannerBottomSheetState();
}

class _ScannerBottomSheetState extends State<_ScannerBottomSheet> {
  bool _continuous = false;
  bool _scanned = false;
  bool _notFound = false;
  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Settings'dan doimiy skanerlash default holatini yukla
    final saved = sl<HiveService>().getSetting('continuous_scan') ?? 'false';
    _continuous = saved == 'true';
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _handleBarcode(String barcode) {
    HapticFeedback.mediumImpact();
    final hive = sl<HiveService>();
    try {
      hive.getProductByBarcode(barcode);
      // Topildi
      if (mounted) {
        context.read<PosBloc>().add(BarcodeScanned(barcode));
      }
      if (!_continuous) {
        Navigator.pop(context);
      } else {
        setState(() {
          _scanned = true;
          _notFound = false;
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _scanned = false);
        });
      }
    } catch (_) {
      // Topilmadi
      HapticFeedback.heavyImpact();
      setState(() {
        _notFound = true;
        _scanned = false;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _notFound = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
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
                Text(
                  'Barkod skanerlash',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Text('Doimiy',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    Switch(
                      value: _continuous,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                      onChanged: (v) =>
                          setState(() => _continuous = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Scanner
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcode =
                          capture.barcodes.firstOrNull?.rawValue;
                      if (barcode != null && !_scanned) {
                        _handleBarcode(barcode);
                      }
                    },
                  ),
                ),
                // Success overlay
                if (_scanned)
                  Container(
                    color: AppColors.success.withValues(alpha: 0.25),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_circle,
                        color: AppColors.success, size: 64),
                  ),
                // Not found overlay
                if (_notFound)
                  Container(
                    color: AppColors.error.withValues(alpha: 0.25),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'Mahsulot topilmadi',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Manual barcode input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Barcode qo\'lda kiriting...',
                      prefixIcon: Icon(Icons.keyboard,
                          color: AppColors.textSecondary),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        _handleBarcode(v.trim());
                        _manualCtrl.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final v = _manualCtrl.text.trim();
                    if (v.isNotEmpty) {
                      _handleBarcode(v);
                      _manualCtrl.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (_continuous)
            Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                  left: 16,
                  right: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Tugash'),
                ),
              ),
            )
          else
            SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom + 12),
        ],
      ),
    );
  }
}

// ── Customer Search Dialog ─────────────────────────────────────────

class _CustomerSearchDialog extends StatefulWidget {
  final PosBloc bloc;
  const _CustomerSearchDialog({required this.bloc});
  @override
  State<_CustomerSearchDialog> createState() =>
      _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<_CustomerSearchDialog> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  CustomerModel? _found;
  bool _searched = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = false;
      _found = null;
    });
    try {
      final repo = sl<CustomerRepository>();
      final customer = await repo.getByPhone(phone);
      setState(() {
        _loading = false;
        _found = customer;
        _searched = true;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Mijoz qidirish',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    style:
                        const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon raqami',
                      prefixIcon: Icon(Icons.phone,
                          color: AppColors.textSecondary),
                      hintText: '+998901234567',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(Icons.search,
                          color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_searched && _found == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_off,
                        color: AppColors.error, size: 16),
                    SizedBox(width: 8),
                    Text('Mijoz topilmadi',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            if (_found != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _found!.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ],
                    ),
                    if (_found!.discountPercent > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_found!.discountPercent.toStringAsFixed(0)}% chegirma',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        if (_found != null)
          ElevatedButton(
            onPressed: () {
              widget.bloc.add(CustomerSelected(_found));
              Navigator.pop(context);
            },
            child: const Text('Tanlash'),
          ),
      ],
    );
  }
}

// ── TASK-FM06: Shift BottomSheet ───────────────────────────────────

class _ShiftBottomSheet extends StatefulWidget {
  const _ShiftBottomSheet();
  @override
  State<_ShiftBottomSheet> createState() => _ShiftBottomSheetState();
}

class _ShiftBottomSheetState extends State<_ShiftBottomSheet> {
  final _balanceCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  final _shiftService = sl<ShiftService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _shiftService.checkCurrentShift();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isOpen = _shiftService.isOpen;
    final shift = _shiftService.currentShift;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: isOpen ? AppColors.success : AppColors.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isOpen ? 'Smena ochiq' : 'Smena yopiq',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isOpen && shift != null) ...[
            // Stats
            _StatRow(
                label: 'Sotuvlar soni',
                value: '${shift.saleCount} ta'),
            const SizedBox(height: 8),
            _StatRow(
              label: 'Jami summa',
              value:
                  '${shift.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} UZS',
            ),
            const SizedBox(height: 8),
            _StatRow(
              label: 'Davomiylik',
              value: _duration(shift.openedAt),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _closeShift,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text('Smena yopish',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            // Open shift
            TextField(
              controller: _balanceCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Boshlang\'ich balans (UZS)',
                prefixIcon: Icon(Icons.account_balance_wallet,
                    color: AppColors.textSecondary),
                hintText: '0',
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _openShift,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text('Smena ochish',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _openShift() async {
    // PIN verification
    final confirmed = await _showPinDialog(context);
    if (!confirmed) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balance =
          double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;
      await _shiftService.openShift(openingBalance: balance);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Smena ochishda xatolik';
      });
    }
  }

  Future<void> _closeShift() async {
    // PIN verification
    final confirmed = await _showPinDialog(context);
    if (!confirmed) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _shiftService.closeShift();
      if (mounted) Navigator.pop(context, false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Smena yopishda xatolik';
      });
    }
  }

  Future<bool> _showPinDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _PinVerifyDialog(),
    );
    return result ?? false;
  }

  String _duration(DateTime openedAt) {
    final diff = DateTime.now().difference(openedAt);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}s ${m}daqiqa';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── PIN Verification Dialog ─────────────────────────────────────────

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  String _pin = '';

  void _onKey(String key) {
    if (key == 'C') {
      setState(() => _pin = '');
      return;
    }
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    final newPin = _pin + key;
    setState(() => _pin = newPin);
    if (newPin.length == 4) {
      // 4 xona kiritildi — tasdiqlash
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'PIN tasdiqlash',
        style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: filled ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Numpad
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫']
                .map((k) => _PinDialogKey(label: k, onTap: () => _onKey(k)))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Bekor',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _PinDialogKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PinDialogKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: label == 'C'
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: label == 'C' ? AppColors.error : AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../data/remote/shift_service.dart';
import 'bloc/shift_bloc.dart';
import 'bloc/shift_event.dart';
import 'bloc/shift_state.dart';

class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShiftBloc(shiftService: sl<ShiftService>())
        ..add(ShiftCheckRequested()),
      child: const _ShiftBody(),
    );
  }
}

class _ShiftBody extends StatelessWidget {
  const _ShiftBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftBloc, ShiftState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.success,
            ),
          );
          // Smena yopilganda yoki ochilganda orqaga qayt
          if (state.status == ShiftStatus.closed ||
              state.status == ShiftStatus.open) {
            if (context.canPop()) context.pop();
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
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: Text(
              state.isOpen ? 'Smena boshqaruvi' : 'Smena ochish',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) context.pop();
              },
            ),
          ),
          body: state.status == ShiftStatus.loading
              ? const _ShiftLoading()
              : state.isOpen
                  ? _ShiftOpenView(shift: state.shift!)
                  : const _ShiftClosedView(),
        );
      },
    );
  }
}

// ── Loading ─────────────────────────────────────────────────────────

class _ShiftLoading extends StatelessWidget {
  const _ShiftLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Yuklanmoqda...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Smena Yopiq ─────────────────────────────────────────────────────

class _ShiftClosedView extends StatefulWidget {
  const _ShiftClosedView();

  @override
  State<_ShiftClosedView> createState() => _ShiftClosedViewState();
}

class _ShiftClosedViewState extends State<_ShiftClosedView> {
  final _balanceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _openShift() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    context.read<ShiftBloc>().add(
          ShiftOpenRequested(openingBalance: balance, note: note),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smena yopiq banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.warning,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Smena yopiq',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sotuvlarni boshlash uchun smena oching',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Boshlang'ich balans
            const Text(
              "Boshlang'ich balans",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _balanceCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Miqdor (UZS)',
                hintText: '0',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                    color: AppColors.textSecondary),
                suffixText: 'UZS',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) {
                  return 'Raqam kiriting';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Izoh
            const Text(
              'Izoh (ixtiyoriy)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                hintText: 'Ixtiyoriy izoh yozing...',
                prefixIcon: Icon(Icons.notes_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 40),

            // Smena ochish tugmasi
            BlocBuilder<ShiftBloc, ShiftState>(
              builder: (context, state) {
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: state.status == ShiftStatus.loading
                        ? null
                        : _openShift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: state.status == ShiftStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'SMENA OCHISH',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smena Ochiq ─────────────────────────────────────────────────────

class _ShiftOpenView extends StatelessWidget {
  final ShiftStats shift;
  const _ShiftOpenView({required this.shift});

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(shift.openedAt);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Smena holati kartasi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.success, Color(0xFF1E7E34)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smena Ochiq',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Boshlangan: ${_formatDate(shift.openedAt)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistika
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sotuvlar soni',
                  value: '${shift.saleCount}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.payments_rounded,
                  label: 'Jami summa',
                  value: _fmt(shift.totalAmount),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Smena yopish tugmasi
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showCloseDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.stop_circle_rounded),
              label: const Text(
                'SMENA YOPISH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context) {
    final bloc = context.read<ShiftBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: bloc,
        child: _CloseShiftSheet(shift: shift),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h soat $m daqiqa';
    return '$m daqiqa';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(double v) => '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} UZS';
}

// ── Stat Card ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Smena Yopish Sheet ───────────────────────────────────────────────

class _CloseShiftSheet extends StatefulWidget {
  final ShiftStats shift;
  const _CloseShiftSheet({required this.shift});

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _balanceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _confirmClose() {
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    context.read<ShiftBloc>().add(
          ShiftCloseRequested(closingBalance: balance, note: note),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Smenani yopish',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Smenani yopishni tasdiqlaysizmi? '
              'Bugungi ${widget.shift.saleCount} ta sotuv hisoblanadi.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Yopilish balansi
            TextField(
              controller: _balanceCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Yopilish balansi (ixtiyoriy)",
                hintText: '0',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                    color: AppColors.textSecondary),
                suffixText: 'UZS',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                prefixIcon:
                    Icon(Icons.notes_rounded, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Bekor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_rounded, size: 18),
                    label: const Text(
                      'Yopish',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
}

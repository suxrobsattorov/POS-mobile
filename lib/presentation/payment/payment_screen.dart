import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../pos/bloc/pos_bloc.dart';
import '../pos/bloc/pos_event.dart';
import '../pos/bloc/pos_state.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final Map<int, double> _amounts = {};
  int? _selectedMethodId;
  String _numpad = '';
  double _total = 0;
  Timer? _autoCloseTimer;
  bool _paymentDone = false;

  void _recalc() =>
      setState(() => _total = _amounts.values.fold(0, (s, v) => s + v));

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosBloc, PosState>(
      listener: (context, state) {
        if (state.status == PosStatus.success && !_paymentDone) {
          _paymentDone = true;
          _showSuccessSheet(context, state);
        }
      },
      builder: (context, state) {
        final due = state.netAmount;
        final change = _total - due;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Text("To'lov"),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    _fmt(due),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Savat summary (ExpansionTile)
                      _CartSummaryTile(state: state),
                      const SizedBox(height: 16),

                      // To'lov usullari header
                      const Text(
                        "To'lov usuli",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Payment methods — 2-column grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: state.paymentMethods.length,
                        itemBuilder: (context, i) {
                          final m = state.paymentMethods[i];
                          final sel = _selectedMethodId == m.id;
                          final amt = _amounts[m.id];
                          return _PaymentMethodCard(
                            name: m.name,
                            type: m.type,
                            amount: amt,
                            selected: sel,
                            onTap: () => setState(() {
                              _selectedMethodId = m.id;
                              _numpad = '';
                            }),
                          );
                        },
                      ),

                      // Summary card
                      if (_total > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              _SummaryRow('Jami:', _fmt(due)),
                              const SizedBox(height: 6),
                              _SummaryRow('Kiritildi:', _fmt(_total),
                                  color: AppColors.success),
                              if (change > 0) ...[
                                const Divider(
                                    color: AppColors.border, height: 16),
                                _SummaryRow(
                                  'Qaytim:',
                                  _fmt(change),
                                  color: AppColors.primary,
                                  bold: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Numpad
              if (_selectedMethodId != null)
                Container(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Miqdor:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _numpad.isEmpty ? '0' : _numpad,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 4x3 Numpad
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        children: [
                          _NumKey(
                              label: '7',
                              onTap: () => _digit('7'),
                              height: 56),
                          _NumKey(
                              label: '8',
                              onTap: () => _digit('8'),
                              height: 56),
                          _NumKey(
                              label: '9',
                              onTap: () => _digit('9'),
                              height: 56),
                          _NumKey(
                              label: '⌫',
                              onTap: _delete,
                              special: true,
                              height: 56),
                          _NumKey(
                              label: '4',
                              onTap: () => _digit('4'),
                              height: 56),
                          _NumKey(
                              label: '5',
                              onTap: () => _digit('5'),
                              height: 56),
                          _NumKey(
                              label: '6',
                              onTap: () => _digit('6'),
                              height: 56),
                          _NumKey(
                              label: 'C',
                              onTap: _clear,
                              special: true,
                              height: 56),
                          _NumKey(
                              label: '1',
                              onTap: () => _digit('1'),
                              height: 56),
                          _NumKey(
                              label: '2',
                              onTap: () => _digit('2'),
                              height: 56),
                          _NumKey(
                              label: '3',
                              onTap: () => _digit('3'),
                              height: 56),
                          _NumKey(
                              label: '.',
                              onTap: () => _digit('.'),
                              height: 56),
                          // Bottom row — C, 0, ., backspace
                          // Qo'shimcha qator: "To'lov qo'shish" + "0"
                          _NumKey(
                              label: 'Aniq',
                              onTap: () => _setExact(due),
                              special: true,
                              small: true,
                              height: 56),
                          _NumKey(
                              label: '0',
                              onTap: () => _digit('0'),
                              height: 56),
                          _NumKey(
                              label: '00',
                              onTap: () {
                                _digit('0');
                                _digit('0');
                              },
                              height: 56),
                          _NumKey(
                              label: '+',
                              onTap: _addPayment,
                              special: true,
                              height: 56),
                        ],
                      ),
                      // To'lov qo'shish button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _addPayment,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                            ),
                            child: Text(
                              _selectedMethodId != null
                                  ? "To'lov qo'shish (${_numpad.isEmpty ? '0' : _numpad})"
                                  : "To'lov qo'shish",
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Confirm button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _total >= due && _amounts.isNotEmpty
                            ? () => _confirm(context)
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: state.status == PosStatus.processingPayment
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'TASDIQLASH',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _digit(String d) {
    if (_selectedMethodId == null) return;
    if (d == '.' && _numpad.contains('.')) return;
    setState(() {
      _numpad += d;
      _amounts[_selectedMethodId!] = double.tryParse(_numpad) ?? 0;
      _recalc();
    });
  }

  void _delete() {
    if (_numpad.isEmpty) return;
    setState(() {
      _numpad = _numpad.substring(0, _numpad.length - 1);
      _amounts[_selectedMethodId!] = double.tryParse(_numpad) ?? 0;
      _recalc();
    });
  }

  void _clear() {
    setState(() {
      _numpad = '';
      if (_selectedMethodId != null) _amounts.remove(_selectedMethodId);
      _recalc();
    });
  }

  void _setExact(double due) {
    if (_selectedMethodId == null) return;
    setState(() {
      _numpad = due.toStringAsFixed(0);
      _amounts[_selectedMethodId!] = due;
      _recalc();
    });
  }

  void _addPayment() {
    if (_selectedMethodId == null || _numpad.isEmpty) return;
    final v = double.tryParse(_numpad) ?? 0;
    if (v <= 0) return;
    setState(() {
      _amounts[_selectedMethodId!] = v;
      _numpad = '';
      _recalc();
    });
  }

  void _confirm(BuildContext context) {
    final payments = _amounts.entries
        .where((e) => e.value > 0)
        .map((e) => SalePaymentEntry(e.key, e.value))
        .toList();
    context.read<PosBloc>().add(SaleSubmitted(payments));
  }

  void _showSuccessSheet(BuildContext context, PosState state) {
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ReceiptBottomSheet(
        change: _total - state.netAmount,
        onClose: () {
          _autoCloseTimer?.cancel();
          Navigator.pop(ctx);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');
}

// ── Cart Summary ExpansionTile ─────────────────────────────────────

class _CartSummaryTile extends StatelessWidget {
  final PosState state;
  const _CartSummaryTile({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.cartItems.length} ta mahsulot',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                '${_fmt(state.netAmount)} UZS',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          children: [
            const Divider(color: AppColors.border, height: 1),
            ...state.cartItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.quantity.toInt()} x ${_fmt(item.product.sellPrice)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt(item.subtotal),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                )),
            if (state.discountAmount > 0) ...[
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chegirma:',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                    Text(
                      '-${_fmt(state.discountAmount)} UZS',
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
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

// ── Payment Method Card ────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final String name;
  final String type;
  final double? amount;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.name,
    required this.type,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  _icon(type),
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 26,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (amount != null && amount! > 0)
                      Text(
                        '${amount!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} UZS',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ],
            ),
            // Selected check overlay
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String t) {
    switch (t.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'click':
        return Icons.bolt_rounded;
      case 'payme':
        return Icons.qr_code_rounded;
      default:
        return Icons.payment_rounded;
    }
  }
}

// ── Summary Row ────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String l;
  final String v;
  final Color? color;
  final bool bold;
  const _SummaryRow(this.l, this.v, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l,
            style:
                const TextStyle(color: AppColors.textSecondary)),
        Text(
          v,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.w500,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

// ── NumKey Widget ──────────────────────────────────────────────────

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool special;
  final bool small;
  final double height;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.special = false,
    this.small = false,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: special
              ? AppColors.surfaceVariant
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: special
                ? AppColors.warning
                : AppColors.textPrimary,
            fontSize: small ? 12 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Receipt Success BottomSheet ────────────────────────────────────

class _ReceiptBottomSheet extends StatefulWidget {
  final double change;
  final VoidCallback onClose;

  const _ReceiptBottomSheet({
    required this.change,
    required this.onClose,
  });

  @override
  State<_ReceiptBottomSheet> createState() =>
      _ReceiptBottomSheetState();
}

class _ReceiptBottomSheetState
    extends State<_ReceiptBottomSheet> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
          // Success icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 44),
          ),
          const SizedBox(height: 16),
          const Text(
            "To'lov muvaffaqiyatli!",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.change > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Qaytim: ${widget.change.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} UZS',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // PDF saqlash
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF saqlash...')),
                );
              },
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF saqlash'),
            ),
          ),
          const SizedBox(height: 10),

          // Yopish
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  'Yopish ($_countdown s)'),
            ),
          ),
        ],
      ),
    );
  }
}

class SaleSuccessInfo {
  final String saleNumber;
  final double change;
  SaleSuccessInfo({required this.saleNumber, required this.change});
}

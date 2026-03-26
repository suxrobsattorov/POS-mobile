import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hive = sl<HiveService>();
  String _currentUrl = 'http://localhost:8080/api/v1';
  String _shopName = '';
  String _cashierName = '';
  bool _continuousScan = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _hive.getUser();
    if (!mounted) return;
    setState(() {
      _currentUrl =
          prefs.getString('api_base_url') ?? 'http://localhost:8080/api/v1';
      _shopName = _hive.getShopName();
      _cashierName = (user != null)
          ? (user.fullName.isNotEmpty ? user.fullName : user.username)
          : '-';
      _continuousScan = (_hive.getSetting('continuous_scan') ?? 'false') == 'true';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Sozlamalar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kassir ma'lumotlari
          _SectionHeader(title: 'Kassir'),
          _InfoTile(
            icon: Icons.person_rounded,
            title: 'Kassir',
            value: _cashierName,
          ),
          _InfoTile(
            icon: Icons.store_rounded,
            title: 'Do\'kon nomi',
            value: _shopName,
          ),
          const SizedBox(height: 16),

          // Server sozlamalari
          _SectionHeader(title: 'Ulanish'),
          _SettingsTile(
            icon: Icons.link_rounded,
            title: 'API Server manzili',
            subtitle: _currentUrl,
            onTap: () => _showApiUrlDialog(context),
          ),
          const SizedBox(height: 16),

          // Skaner sozlamalari
          _SectionHeader(title: 'Skaner'),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doimiy skanerlash',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Har skanlashda avtomatik qo\'shish',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _continuousScan,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  onChanged: (v) async {
                    setState(() => _continuousScan = v);
                    await _hive.saveSetting(
                        'continuous_scan', v.toString());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Versiya
          _SectionHeader(title: 'Ilova'),
          const _InfoTile(
            icon: Icons.info_outline_rounded,
            title: 'Versiya',
            value: '1.0.0',
          ),
          const SizedBox(height: 32),

          // Chiqish
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Chiqish',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiUrlDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        prefs.getString('api_base_url') ?? 'http://localhost:8080/api/v1';
    final ctrl = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'API Manzili',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'http://192.168.1.100:8080/api/v1',
              prefixIcon:
                  Icon(Icons.link, color: AppColors.textSecondary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'URL kiriting';
              if (!v.startsWith('http')) {
                return 'http:// yoki https:// bilan boshlang';
              }
              return null;
            },
            keyboardType: TextInputType.url,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final url = ctrl.text.trim();
                await prefs.setString('api_base_url', url);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _currentUrl = url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'URL saqlandi. Qayta ishga tushiring.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Chiqish',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Tizimdan chiqmoqchimisiz?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _hive.clearAuth();
      if (mounted) context.go('/login');
    }
  }
}

// ── Helper Widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

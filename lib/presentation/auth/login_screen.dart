import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/sync_service.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: sl<AuthRepository>(),
        hiveService: sl<HiveService>(),
        syncService: sl<SyncService>(),
      ),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();
  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _usePin = false;
  String _pin = '';
  bool _hasError = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _usePin = _tabController.index == 1;
        _hasError = false;
      });
      if (_tabController.index == 1) setState(() => _pin = '');
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/pos');
        }
        if (state is AuthError) {
          setState(() => _hasError = true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'POS Kassa',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Professional savdo tizimi',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 36),

                // Error banner
                if (_hasError)
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is! AuthError) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.message,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    tabs: const [
                      Tab(text: 'Login / Parol'),
                      Tab(text: 'PIN kod'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: _usePin ? 340 : 220,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(),
                      _buildPinForm(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Sozlamalar tugmasi
                TextButton.icon(
                  onPressed: () => _showApiUrlDialog(context),
                  icon: Icon(Icons.settings_outlined,
                      size: 16, color: AppColors.textSecondary),
                  label: Text(
                    'Sozlamalar',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _usernameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Login',
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
            ),
            validator: (v) =>
                (v?.isEmpty ?? true) ? 'Login kiriting' : null,
            onChanged: (_) {
              if (_hasError) setState(() => _hasError = false);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: AppColors.textPrimary),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Parol',
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v?.isEmpty ?? true) ? 'Parol kiriting' : null,
            onFieldSubmitted: (_) => _submitLogin(),
            onChanged: (_) {
              if (_hasError) setState(() => _hasError = false);
            },
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: state is AuthLoading ? null : _submitLogin,
                child: state is AuthLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Kirish',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinForm() {
    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        // PIN grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 12,
          itemBuilder: (context, i) {
            final labels = [
              '1','2','3','4','5','6','7','8','9','C','0','⌫'
            ];
            final label = labels[i];
            return _PinKey(
              label: label,
              onTap: () {
                if (_hasError) setState(() => _hasError = false);
                if (label == '⌫') {
                  if (_pin.isNotEmpty) {
                    setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  }
                } else if (label == 'C') {
                  setState(() => _pin = '');
                } else if (_pin.length < 4) {
                  setState(() => _pin += label);
                  if (_pin.length == 4) {
                    context.read<AuthBloc>().add(PinLoginRequested(_pin));
                  }
                }
              },
            );
          },
        ),
        const SizedBox(height: 16),
        BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
          if (state is AuthLoading) {
            return const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _hasError = false);
      context.read<AuthBloc>().add(
            LoginRequested(
                _usernameCtrl.text.trim(), _passwordCtrl.text),
          );
    }
  }

  Future<void> _showApiUrlDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString('api_base_url') ?? 'http://localhost:8080/api/v1';
    final ctrl = TextEditingController(text: currentUrl);
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
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
              if (v == null || v.trim().isEmpty) {
                return 'URL kiriting';
              }
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
            child: Text('Bekor',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final url = ctrl.text.trim();
                await prefs.setString('api_base_url', url);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL saqlandi. Qayta ishga tushiring.'),
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
}

class _PinKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PinKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: label == 'C'
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: label == 'C' ? AppColors.error : AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

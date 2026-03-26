import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/remote/auth_repository.dart';
import '../../../data/remote/sync_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final HiveService _hiveService;
  final SyncService _syncService;

  AuthBloc({
    required AuthRepository authRepository,
    required HiveService hiveService,
    required SyncService syncService,
  })  : _authRepository = authRepository,
        _hiveService = hiveService,
        _syncService = syncService,
        super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheck);
    on<LoginRequested>(_onLogin);
    on<PinLoginRequested>(_onPinLogin);
    on<LogoutRequested>(_onLogout);
  }

  void _onCheck(CheckAuthStatus event, Emitter<AuthState> emit) {
    if (_hiveService.isLoggedIn) {
      final user = _hiveService.getUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
        _syncService.startBackgroundSync();
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.login(event.username, event.password);
      await _hiveService.saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await _syncService.syncAll();
      _syncService.startBackgroundSync();
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthError(e.toString().contains('401') ? 'Login yoki parol noto\'g\'ri' : 'Xatolik yuz berdi'));
    }
  }

  Future<void> _onPinLogin(PinLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.loginWithPin(event.pin);
      await _hiveService.saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await _syncService.syncAll();
      _syncService.startBackgroundSync();
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthError('PIN noto\'g\'ri'));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    _syncService.stopBackgroundSync();
    await _syncService.forceSyncPendingSales();
    await _authRepository.logout();
    await _hiveService.clearAuth();
    emit(AuthUnauthenticated());
  }
}

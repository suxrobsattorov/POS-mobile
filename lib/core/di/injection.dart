import 'package:alice/alice.dart';
import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/sale_repository.dart';
import '../../data/remote/sync_service.dart';
import '../../data/remote/product_repository.dart';
import '../../data/remote/category_repository.dart';
import '../../data/remote/payment_method_repository.dart';
import '../../data/remote/customer_repository.dart';
import '../../data/remote/shift_service.dart';

final GetIt sl = GetIt.instance;

/// Global Alice instance for HTTP inspection.
/// Shake device to open inspector, or tap the floating notification bubble.
final Alice alice = Alice(
  showNotification: true,
  showInspectorOnShake: true,
);

Future<void> setupDependencies() async {
  sl.registerLazySingleton<HiveService>(() => HiveService());
  sl.registerLazySingleton<ApiClient>(
      () => ApiClient(sl<HiveService>(), alice));
  sl.registerLazySingleton<AuthRepository>(
      () => AuthRepository(sl<ApiClient>()));
  sl.registerLazySingleton<SaleRepository>(
      () => SaleRepository(sl<ApiClient>()));
  sl.registerLazySingleton<SyncService>(
      () => SyncService(sl<ApiClient>(), sl<HiveService>()));
  sl.registerLazySingleton<ProductRepository>(
      () => ProductRepository(sl<ApiClient>(), hiveService: sl<HiveService>()));
  sl.registerLazySingleton<CategoryRepository>(
      () => CategoryRepository(sl<ApiClient>()));
  sl.registerLazySingleton<PaymentMethodRepository>(
      () => PaymentMethodRepository(sl<ApiClient>()));
  sl.registerLazySingleton<CustomerRepository>(
      () => CustomerRepository(sl<ApiClient>()));
  sl.registerLazySingleton<ShiftService>(
      () => ShiftService(sl<ApiClient>()));
}

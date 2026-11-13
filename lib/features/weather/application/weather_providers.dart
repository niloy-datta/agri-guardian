import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/fields/application/fields_providers.dart'
    show connectivityServiceProvider;
import '../data/weather_risk_repository.dart';
import '../domain/weather_risk_models.dart';

/// Demo-only until a backend weather-risk endpoint exists - see
/// [DemoWeatherRiskRepository]. Swap this single provider for a real
/// implementation later; the screen reads only the contract.
final weatherRiskRepositoryProvider = Provider<WeatherRiskRepository>((ref) {
  return DemoWeatherRiskRepository();
});

final weatherRiskSnapshotProvider =
    FutureProvider.autoDispose<WeatherRiskSnapshot>((ref) {
      return ref.watch(weatherRiskRepositoryProvider).fetchSnapshot();
    });

/// True while the device has no usable network interface. Reuses the
/// app-wide [connectivityServiceProvider]; seeds with a one-off check
/// because the change stream is not guaranteed to emit up front.
final weatherIsOfflineProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final connectivity = ref.watch(connectivityServiceProvider);
  yield !await connectivity.isConnected();
  yield* connectivity.onConnectivityChanged().map((connected) => !connected);
});

import 'package:connectivity_plus/connectivity_plus.dart';

/// Real device connectivity, not a hardcoded `true`.
///
/// This only reports whether the device has a network interface up
/// (Wi-Fi/mobile/ethernet) - it cannot prove the backend is actually
/// reachable, since a captive portal or a down API server both look like
/// "connected" from here. Callers must still handle [ApiClient] failures
/// (timeouts, connection errors) even when [isConnected] returns true; this
/// service exists to give an honest "you're offline" message *before*
/// attempting a call, not to replace error handling after one.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return _hasUsableInterface(results);
  }

  /// Emits the current connectivity state immediately, then again on every
  /// change, so UI (e.g. an offline banner) can react live.
  Stream<bool> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged.map(_hasUsableInterface);
  }

  bool _hasUsableInterface(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

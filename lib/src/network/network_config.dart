import 'dart:async';

/// Performs an app-defined internet reachability check.
///
/// Return `true` only when the backend or internet target required by the app
/// is reachable. The callback may perform a lightweight health request through
/// an app-owned client.
typedef NexioConnectivityProbe = FutureOr<bool> Function();

/// Controls active connectivity checks performed by Nexio.
class NexioNetworkConfig {
  /// Creates network verification configuration.
  ///
  /// Parameters:
  /// - [connectivityProbe] verifies real reachability after the device reports
  ///   an available network interface. Defaults to interface status only.
  /// - [verifyBeforeRequest] runs [connectivityProbe] before each request.
  ///   Defaults to `false` to avoid adding latency to every API call.
  const NexioNetworkConfig({
    this.connectivityProbe,
    this.verifyBeforeRequest = false,
  });

  /// Optional app-defined reachability check.
  final NexioConnectivityProbe? connectivityProbe;

  /// Whether requests actively verify connectivity before entering Dio.
  final bool verifyBeforeRequest;
}

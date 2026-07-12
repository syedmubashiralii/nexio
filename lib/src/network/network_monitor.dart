import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../events/nexio_events.dart';
import 'network_config.dart';

/// Monitors device connectivity for Nexio.
class NexioNetworkMonitor {
  /// Creates a network monitor.
  ///
  /// Parameters:
  /// - [eventBus] receives network change events.
  /// - [connectivity] injects a connectivity instance for tests.
  /// - [config] controls optional active reachability checks.
  NexioNetworkMonitor({
    required this.eventBus,
    Connectivity? connectivity,
    this.config = const NexioNetworkConfig(),
  }) : _connectivity = connectivity ?? Connectivity();

  /// Event bus receiving connectivity events.
  final NexioEventBus eventBus;

  /// Active connectivity verification configuration.
  final NexioNetworkConfig config;

  final Connectivity _connectivity;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  /// Current best-effort online state.
  bool get isOnline => _isOnline;

  /// Emits `true` or `false` whenever connectivity changes.
  Stream<bool> get changes => _changes.stream;

  /// Emits when the device appears online.
  Stream<bool> get online => changes.where((isOnline) => isOnline);

  /// Emits when the device appears offline.
  Stream<bool> get offline => changes.where((isOnline) => !isOnline);

  /// Starts monitoring connectivity.
  Future<void> start() async {
    await checkNow();
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      unawaited(_refreshFromInterfaces(results));
    });
  }

  /// Checks current interface state and the optional reachability probe.
  ///
  /// Returns `true` when a usable network interface exists and the configured
  /// probe, when present, succeeds.
  Future<bool> checkNow() async {
    try {
      final interfaces = await _connectivity.checkConnectivity();
      return _refreshFromInterfaces(interfaces);
    } catch (_) {
      if (config.connectivityProbe == null) {
        return _isOnline;
      }
      return _runProbe();
    }
  }

  /// Stops monitoring connectivity.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> _refreshFromInterfaces(
    List<ConnectivityResult> results,
  ) async {
    if (!_hasNetwork(results)) {
      _setOnline(false);
      return false;
    }

    final probe = config.connectivityProbe;
    if (probe == null) {
      _setOnline(true);
      return true;
    }

    return _runProbe();
  }

  Future<bool> _runProbe() async {
    final probe = config.connectivityProbe;
    if (probe == null) {
      return _isOnline;
    }
    try {
      final reachable = await Future<bool>.value(probe());
      _setOnline(reachable);
      return reachable;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  void _setOnline(bool value) {
    if (_isOnline == value) {
      return;
    }
    _isOnline = value;
    if (!_changes.isClosed) {
      _changes.add(value);
    }
    eventBus.emit(NexioNetworkChangedEvent(value));
  }
}

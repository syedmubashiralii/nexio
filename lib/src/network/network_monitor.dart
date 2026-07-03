import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../events/nexio_events.dart';

/// Monitors device connectivity for Nexio.
class NexioNetworkMonitor {
  /// Creates a network monitor.
  ///
  /// Parameters:
  /// - [eventBus] receives network change events.
  /// - [connectivity] injects a connectivity instance for tests.
  NexioNetworkMonitor({
    required this.eventBus,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  /// Event bus receiving connectivity events.
  final NexioEventBus eventBus;

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
    final initial = await _connectivity.checkConnectivity();
    _setOnline(_hasNetwork(initial));
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      _setOnline(_hasNetwork(results));
    });
  }

  /// Stops monitoring connectivity.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
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

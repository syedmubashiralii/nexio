import 'dart:async';

import '../models/nexio_response.dart';

/// Base class for every Nexio runtime event.
sealed class NexioEvent {
  /// Creates a runtime event.
  ///
  /// Parameters:
  /// - [timestamp] records when the event was emitted.
  const NexioEvent({required this.timestamp});

  /// Time when the event was emitted.
  final DateTime timestamp;
}

/// Emitted when a request is scheduled to start.
class NexioRequestStartedEvent extends NexioEvent {
  /// Creates a request-started event.
  ///
  /// Parameters:
  /// - [method] is the HTTP method.
  /// - [url] is the resolved request URL.
  /// - [tag] is the optional cancellation tag.
  /// - [group] is the optional cancellation group.
  NexioRequestStartedEvent({
    required this.method,
    required this.url,
    this.tag,
    this.group,
  }) : super(timestamp: DateTime.now());

  /// HTTP method.
  final String method;

  /// Resolved request URL.
  final String url;

  /// Optional cancellation tag.
  final String? tag;

  /// Optional cancellation group.
  final String? group;
}

/// Emitted when a request succeeds.
class NexioRequestSuccessEvent<T> extends NexioEvent {
  /// Creates a request-success event.
  ///
  /// Parameters:
  /// - [response] is the successful typed response.
  NexioRequestSuccessEvent(this.response) : super(timestamp: DateTime.now());

  /// Successful typed response.
  final NexioResponse<T> response;
}

/// Emitted when a request fails.
class NexioRequestFailedEvent extends NexioEvent {
  /// Creates a request-failed event.
  ///
  /// Parameters:
  /// - [error] is the thrown error.
  /// - [stackTrace] is the original stack trace when available.
  NexioRequestFailedEvent(this.error, [this.stackTrace])
      : super(timestamp: DateTime.now());

  /// Request failure.
  final Object error;

  /// Failure stack trace.
  final StackTrace? stackTrace;
}

/// Emitted when a request is cancelled.
class NexioRequestCancelledEvent extends NexioEvent {
  /// Creates a request-cancelled event.
  ///
  /// Parameters:
  /// - [reason] is the cancellation reason.
  NexioRequestCancelledEvent(this.reason) : super(timestamp: DateTime.now());

  /// Cancellation reason.
  final String reason;
}

/// Emitted when connectivity changes.
class NexioNetworkChangedEvent extends NexioEvent {
  /// Creates a network-change event.
  ///
  /// Parameters:
  /// - [isOnline] is `true` when the device has a non-none network transport.
  NexioNetworkChangedEvent(this.isOnline) : super(timestamp: DateTime.now());

  /// Current online state.
  final bool isOnline;
}

/// Emitted when a response returns HTTP 401.
class NexioUnauthorizedEvent extends NexioEvent {
  /// Creates an unauthorized event.
  ///
  /// Parameters:
  /// - [url] is the resolved request URL.
  /// - [environment] is the active environment when the response arrived.
  NexioUnauthorizedEvent({
    required this.url,
    required this.environment,
  }) : super(timestamp: DateTime.now());

  /// Resolved request URL that returned 401.
  final String url;

  /// Active environment when the unauthorized response arrived.
  final String environment;
}

/// Broadcast event bus for Nexio lifecycle events.
class NexioEventBus {
  final _controller = StreamController<NexioEvent>.broadcast();

  /// Stream of every Nexio runtime event.
  Stream<NexioEvent> get stream => _controller.stream;

  /// Emits [event] to every listener.
  ///
  /// Parameters:
  /// - [event] is the runtime event to broadcast.
  void emit(NexioEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Closes the event bus.
  Future<void> close() => _controller.close();
}

import 'package:dio/dio.dart';

import '../events/nexio_events.dart';

/// Handle returned for single-request cancellation.
class NexioCancelHandle {
  /// Creates a cancellation handle.
  ///
  /// Parameters:
  /// - [token] is the Dio token used by the request.
  /// - [tag] is the optional tag registered for this request.
  /// - [group] is the optional group registered for this request.
  const NexioCancelHandle({
    required this.token,
    this.tag,
    this.group,
  });

  /// Dio cancellation token.
  final CancelToken token;

  /// Optional cancellation tag.
  final String? tag;

  /// Optional cancellation group.
  final String? group;

  /// Cancels this request.
  ///
  /// Parameters:
  /// - [reason] describes why the request is being cancelled.
  void cancel([String reason = 'Cancelled by NexioCancelHandle']) {
    if (!token.isCancelled) {
      token.cancel(reason);
    }
  }
}

/// Tracks cancellation tokens by tag and group.
class NexioCancellationRegistry {
  /// Creates a cancellation registry.
  ///
  /// Parameters:
  /// - [eventBus] receives cancellation events.
  NexioCancellationRegistry(this.eventBus);

  /// Event bus used for cancellation notifications.
  final NexioEventBus eventBus;

  final Map<String, Set<CancelToken>> _tags = <String, Set<CancelToken>>{};
  final Map<String, Set<CancelToken>> _groups = <String, Set<CancelToken>>{};

  /// Registers [token] with optional [tag] and [group].
  ///
  /// Parameters:
  /// - [token] is the Dio token used by the request.
  /// - [tag] enables tag-based cancellation.
  /// - [group] enables group cancellation.
  NexioCancelHandle register(
    CancelToken token, {
    String? tag,
    String? group,
  }) {
    if (tag != null) {
      _tags.putIfAbsent(tag, () => <CancelToken>{}).add(token);
    }
    if (group != null) {
      _groups.putIfAbsent(group, () => <CancelToken>{}).add(token);
    }
    return NexioCancelHandle(token: token, tag: tag, group: group);
  }

  /// Removes [token] from optional [tag] and [group].
  ///
  /// Parameters:
  /// - [token] is the token to remove.
  /// - [tag] is the tag used during registration.
  /// - [group] is the group used during registration.
  void unregister(CancelToken token, {String? tag, String? group}) {
    if (tag != null) {
      _tags[tag]?.remove(token);
      if (_tags[tag]?.isEmpty ?? false) {
        _tags.remove(tag);
      }
    }
    if (group != null) {
      _groups[group]?.remove(token);
      if (_groups[group]?.isEmpty ?? false) {
        _groups.remove(group);
      }
    }
  }

  /// Cancels every request registered with [tag].
  ///
  /// Parameters:
  /// - [tag] identifies requests to cancel.
  /// - [reason] describes why the requests are being cancelled.
  void cancelTag(String tag, {String reason = 'Cancelled by Nexio tag'}) {
    final tokens = Set<CancelToken>.from(_tags[tag] ?? const <CancelToken>{});
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
    eventBus.emit(NexioRequestCancelledEvent(reason));
  }

  /// Cancels every request registered with [group].
  ///
  /// Parameters:
  /// - [group] identifies requests to cancel.
  /// - [reason] describes why the requests are being cancelled.
  void cancelGroup(String group, {String reason = 'Cancelled by Nexio group'}) {
    final tokens =
        Set<CancelToken>.from(_groups[group] ?? const <CancelToken>{});
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
    eventBus.emit(NexioRequestCancelledEvent(reason));
  }
}

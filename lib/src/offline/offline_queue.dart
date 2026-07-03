import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../events/nexio_events.dart';
import '../models/nexio_metrics.dart';
import '../models/nexio_response.dart';

/// A request stored for offline replay.
class NexioQueuedRequest {
  /// Creates a queued request.
  ///
  /// Parameters:
  /// - [id] uniquely identifies this queued request.
  /// - [method] is the HTTP method.
  /// - [url] is the resolved absolute URL.
  /// - [data] is a JSON-safe request body.
  /// - [queryParameters] are request query parameters.
  /// - [headers] are request headers.
  /// - [createdAt] records when the request was queued.
  const NexioQueuedRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.data,
    required this.queryParameters,
    required this.headers,
    required this.createdAt,
  });

  /// Unique queue identifier.
  final String id;

  /// HTTP method.
  final String method;

  /// Absolute request URL.
  final String url;

  /// JSON-safe request body.
  final Object? data;

  /// Query parameters.
  final Map<String, Object?> queryParameters;

  /// Request headers.
  final Map<String, Object?> headers;

  /// Queue creation time.
  final DateTime createdAt;

  /// Converts this request to JSON.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'method': method,
      'url': url,
      'data': data,
      'queryParameters': queryParameters,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Builds a queued request from [json].
  ///
  /// Parameters:
  /// - [json] is a decoded queue object.
  factory NexioQueuedRequest.fromJson(Map<String, Object?> json) {
    return NexioQueuedRequest(
      id: json['id'].toString(),
      method: json['method'].toString(),
      url: json['url'].toString(),
      data: json['data'],
      queryParameters: _mapOf(json['queryParameters']),
      headers: _mapOf(json['headers']),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  static Map<String, Object?> _mapOf(Object? value) {
    if (value is! Map) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
}

/// Stores no-connectivity failures and replays them later.
class NexioOfflineQueue {
  /// Creates an offline queue.
  ///
  /// Parameters:
  /// - [eventBus] receives replay success or failure events.
  /// - [folderName] is the app support subfolder used for persistence.
  NexioOfflineQueue({
    required this.eventBus,
    this.folderName = 'nexio_offline',
  });

  /// Event bus used for replay events.
  final NexioEventBus eventBus;

  /// App support subfolder used for queue persistence.
  final String folderName;

  final Uuid _uuid = const Uuid();
  File? _file;

  /// Adds a request to the queue and returns its id.
  ///
  /// Parameters:
  /// - [method] is the HTTP method.
  /// - [url] is the resolved absolute URL.
  /// - [data] is the request body.
  /// - [queryParameters] are request query parameters.
  /// - [headers] are request headers.
  Future<String> enqueue({
    required String method,
    required String url,
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
  }) async {
    final request = NexioQueuedRequest(
      id: _uuid.v4(),
      method: method,
      url: url,
      data: _jsonSafe(data),
      queryParameters: queryParameters ?? const <String, Object?>{},
      headers: headers ?? const <String, Object?>{},
      createdAt: DateTime.now(),
    );
    final items = await load();
    items.add(request);
    await _write(items);
    return request.id;
  }

  /// Loads queued requests from disk.
  Future<List<NexioQueuedRequest>> load() async {
    final file = await _queueFile();
    if (!file.existsSync()) {
      return <NexioQueuedRequest>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return <NexioQueuedRequest>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => NexioQueuedRequest.fromJson(<String, Object?>{
                for (final entry in item.entries)
                  entry.key.toString(): entry.value,
              }))
          .toList();
    } catch (_) {
      return <NexioQueuedRequest>[];
    }
  }

  /// Replays queued requests with [dio].
  ///
  /// Parameters:
  /// - [dio] is Nexio's configured Dio instance.
  Future<void> replay(Dio dio) async {
    final items = await load();
    if (items.isEmpty) {
      return;
    }
    final remaining = <NexioQueuedRequest>[];
    for (final item in items) {
      try {
        final response = await dio.request<Object?>(
          item.url,
          data: item.data,
          queryParameters: item.queryParameters,
          options: Options(method: item.method, headers: item.headers),
        );
        eventBus.emit(
          NexioRequestSuccessEvent<Object?>(
            NexioResponse<Object?>(
              data: response.data,
              statusCode: response.statusCode,
              statusMessage: response.statusMessage,
              headers: response.headers.map,
              metrics: NexioMetrics.zero,
              fromCache: false,
              requestOptions: response.requestOptions,
            ),
          ),
        );
      } catch (error, stackTrace) {
        remaining.add(item);
        eventBus.emit(NexioRequestFailedEvent(error, stackTrace));
      }
    }
    await _write(remaining);
  }

  Future<void> _write(List<NexioQueuedRequest> items) async {
    final file = await _queueFile();
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  Future<File> _queueFile() async {
    final existing = _file;
    if (existing != null) {
      return existing;
    }
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/$folderName');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    _file = File('${directory.path}/queue.json');
    return _file!;
  }

  Object? _jsonSafe(Object? data) {
    try {
      jsonEncode(data);
      return data;
    } on JsonUnsupportedObjectError {
      return data.toString();
    }
  }
}

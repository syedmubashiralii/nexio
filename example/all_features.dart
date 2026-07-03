import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexio/nexio.dart';

/// Copyable examples for every major Nexio feature.
class NexioAllFeaturesExample {
  const NexioAllFeaturesExample._();

  /// Initializes the full runtime once from `main.dart`.
  static void initialize() {
    Nexio.initialize(
      environments: const {
        'test': NexioEnvironment(baseUrl: 'https://test.example.com'),
        'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
        'staging': NexioEnvironment(baseUrl: 'https://staging.example.com'),
        'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
      },
      initialEnvironment: 'dev',
      encryptionConfig: const EncryptionConfig(
        aesCbcKey: '12345678901234567890123456789012',
        aesCbcIv: '1234567890123456',
        aesGcmKey: '12345678901234567890123456789012',
      ),
      defaultEncryptionMode: EncryptionMode.none,
      loggerEnabled: true,
      enableChucker: true,
      defaultLogInChucker: false,
      retryPolicy: const RetryPolicy(retries: 2),
      cacheConfig: const CacheConfig(
        defaultTtl: Duration(minutes: 10),
        enableMemoryCache: true,
        enableDiskCache: true,
      ),
      defaultThreadMode: ThreadMode.auto,
      parseThresholdKb: 64,
      offlineQueueEnabled: true,
      maxConcurrentRequests: 6,
      defaultHeaders: const {'Accept': 'application/json'},
      onUnauthorized: (event) {
        debugPrint('Unauthorized request: ${event.url}');
      },
    );

    Nexio.registerParser<User>(User.parse);
    Nexio.registerParser<List<User>>(User.parseList);
  }

  /// Reads a typed response using a globally registered parser.
  static Future<void> typedGet() async {
    final response = await Nexio.get<List<User>>(
      '/users',
      cachePolicy: CachePolicy.cacheFirst,
      logInChucker: true,
    );

    debugPrint('Loaded ${response.data.length} users');
    debugPrint('Total time: ${response.metrics.totalDuration}');
  }

  /// Switches the selected environment without creating another Dio instance.
  static Future<void> environments() async {
    Nexio.switchEnvironment('production');

    final response = await Nexio.get<Map<String, Object?>>(
      '/health',
      parser: parseMap,
    );

    final special = await Nexio.get<Map<String, Object?>>(
      '/users',
      baseUrlOverride: 'https://special-domain.com',
      parser: parseMap,
    );

    debugPrint(
      'Health: ${response.statusCode}, special: ${special.statusCode}',
    );
  }

  /// Sends common payload types.
  static Future<void> payloads() async {
    final jsonResponse = await Nexio.post<Map<String, Object?>>(
      '/json',
      data: const {'name': 'Nexio'},
      parser: parseMap,
    );

    final formResponse = await Nexio.post<Map<String, Object?>>(
      '/form',
      data: 'email=test@example.com&name=Nexio',
      contentType: Headers.formUrlEncodedContentType,
      parser: parseMap,
    );

    final textResponse = await Nexio.post<String>(
      '/plain-text',
      data: 'hello',
      contentType: Headers.textPlainContentType,
    );

    final bytesResponse = await Nexio.post<Uint8List>(
      '/binary',
      data: Uint8List.fromList([1, 2, 3]),
    );

    debugPrint(
      'Payload results: ${jsonResponse.statusCode}, '
      '${formResponse.statusCode}, ${textResponse.data}, '
      '${bytesResponse.data.length}',
    );
  }

  /// Encrypts selected requests.
  static Future<void> encryption() async {
    final cbc = await Nexio.post<Map<String, Object?>>(
      '/secure-cbc',
      data: const {'amount': 100},
      encryptionMode: EncryptionMode.aesCbc,
      logInChucker: false,
      parser: parseMap,
    );

    final gcm = await Nexio.post<Map<String, Object?>>(
      '/secure-gcm',
      data: const {'amount': 200},
      encryptionMode: EncryptionMode.aesGcm,
      logInChucker: false,
      parser: parseMap,
    );

    debugPrint('Encrypted responses: ${cbc.statusCode}, ${gcm.statusCode}');
  }

  /// Uses automatic or forced background parsing for large payloads.
  static Future<void> threading() async {
    final auto = await Nexio.get<List<User>>(
      '/users',
      threadMode: ThreadMode.auto,
      parseThresholdKb: 32,
    );

    final background = await Nexio.get<List<User>>(
      '/large-users',
      threadMode: ThreadMode.background,
    );

    debugPrint('Parsed: ${auto.data.length}, ${background.data.length}');
  }

  /// Retries transient failures with fixed or exponential backoff.
  static Future<void> retries() async {
    final response = await Nexio.get<Map<String, Object?>>(
      '/unstable',
      retryPolicy: const RetryPolicy(
        retries: 3,
        strategy: RetryStrategy.exponential,
        delay: Duration(milliseconds: 300),
      ),
      parser: parseMap,
    );

    debugPrint('Retry result: ${response.statusCode}');
  }

  /// Shows a per-request loader without forcing a package UI design.
  static Future<void> loader(BuildContext context) async {
    final response = await Nexio.get<Map<String, Object?>>(
      '/slow',
      showLoader: true,
      context: context,
      dismissible: false,
      barrierColor: const Color(0x66000000),
      loaderWidget: const SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      parser: parseMap,
    );

    debugPrint('Loader request: ${response.statusCode}');
  }

  /// Cancels a single request, a tag, or a group.
  static Future<void> cancellation() async {
    final token = CancelToken();

    final future = Nexio.get<Map<String, Object?>>(
      '/profile',
      cancelToken: token,
      cancelTag: 'profile',
      cancelGroup: 'account',
      parser: parseMap,
    );

    token.cancel('User left the screen');
    Nexio.cancelTag('profile');
    Nexio.cancelGroup('account');

    await future.catchError((Object error) {
      debugPrint('Cancelled: $error');
      return NexioResponse<Map<String, Object?>>(
        data: const {},
        statusCode: null,
        statusMessage: null,
        headers: const {},
        metrics: NexioMetrics.zero,
        fromCache: false,
      );
    });
  }

  /// Uses all cache policies.
  static Future<void> caching() async {
    final networkOnly = await Nexio.get<Map<String, Object?>>(
      '/settings',
      cachePolicy: CachePolicy.networkOnly,
      parser: parseMap,
    );

    final networkFirst = await Nexio.get<Map<String, Object?>>(
      '/settings',
      cachePolicy: CachePolicy.networkFirst,
      cacheTtl: const Duration(minutes: 30),
      parser: parseMap,
    );

    final cacheFirst = await Nexio.get<Map<String, Object?>>(
      '/settings',
      cachePolicy: CachePolicy.cacheFirst,
      parser: parseMap,
    );

    final cacheOnly = await Nexio.get<Map<String, Object?>>(
      '/settings',
      cachePolicy: CachePolicy.cacheOnly,
      parser: parseMap,
    );

    debugPrint(
      'Cache flags: ${networkOnly.fromCache}, ${networkFirst.fromCache}, '
      '${cacheFirst.fromCache}, ${cacheOnly.fromCache}',
    );
  }

  /// Queues no-connectivity failures when offline queueing is enabled.
  static Future<void> offlineQueue() async {
    final subscription = Nexio.online.listen((_) {
      debugPrint('Back online. Nexio will replay queued requests.');
    });

    try {
      await Nexio.post<Map<String, Object?>>(
        '/events',
        data: const {'type': 'opened_app'},
        deduplicate: false,
        parser: parseMap,
      );
    } on NexioOfflineQueuedException catch (error) {
      debugPrint('Queued offline request: ${error.queueId}');
    } finally {
      await subscription.cancel();
    }
  }

  /// Uploads images, videos, audio, or documents with progress.
  static Future<void> upload() async {
    final response = await Nexio.upload<Map<String, Object?>>(
      '/media',
      files: const [
        NexioUploadFile(
          fieldName: 'image',
          path: '/storage/emulated/0/DCIM/avatar.jpg',
          contentType: 'image/jpeg',
        ),
        NexioUploadFile(
          fieldName: 'document',
          path: '/storage/emulated/0/Download/contract.pdf',
          contentType: 'application/pdf',
        ),
      ],
      fields: const {'folder': 'profile'},
      cancelTag: 'media-upload',
      onSendProgress: (sent, total) {
        debugPrint('Upload: $sent / $total');
      },
      parser: parseMap,
    );

    debugPrint('Upload result: ${response.statusCode}');
  }

  /// Downloads a file and demonstrates pause, resume, and cancel.
  static Future<void> download() async {
    final task = Nexio.download(
      '/files/report.pdf',
      destinationPath: '/storage/emulated/0/Download/report.pdf',
      onProgress: (received, total) {
        debugPrint('Download: $received / $total');
      },
    );

    await task.pause();
    await task.resume();

    final path = await task.completed;
    debugPrint('Downloaded to $path');
  }

  /// Uses request priority and disables deduplication when every call matters.
  static Future<void> priorityAndDeduplication() async {
    final high = await Nexio.get<Map<String, Object?>>(
      '/checkout/summary',
      priority: RequestPriority.high,
      parser: parseMap,
    );

    final analytics = await Nexio.post<Map<String, Object?>>(
      '/analytics',
      data: const {'event': 'tap'},
      priority: RequestPriority.low,
      deduplicate: false,
      parser: parseMap,
    );

    debugPrint('Priority results: ${high.statusCode}, ${analytics.statusCode}');
  }

  /// Listens to request, network, cancellation, and unauthorized events.
  static Future<void> events() async {
    final subscription = Nexio.events.listen((event) {
      switch (event) {
        case NexioRequestStartedEvent():
          debugPrint('Request started');
        case NexioRequestSuccessEvent():
          debugPrint('Request succeeded');
        case NexioRequestFailedEvent():
          debugPrint('Request failed');
        case NexioRequestCancelledEvent():
          debugPrint('Request cancelled');
        case NexioNetworkChangedEvent():
          debugPrint('Network changed: ${event.isOnline}');
        case NexioUnauthorizedEvent():
          debugPrint('Unauthorized: ${event.url}');
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    await subscription.cancel();
  }

  /// Reads network state and opens logs.
  static void monitoringAndLogs(BuildContext context) {
    debugPrint('Online: ${Nexio.isOnline}');
    debugPrint('Observed requests: ${Nexio.healthSnapshot.total}');

    final onlineSubscription = Nexio.online.listen((_) {
      debugPrint('Device is online');
    });
    unawaited(onlineSubscription.cancel());

    Nexio.showLogs(context);
  }
}

Future<Map<String, Object?>> parseMap(Object? input) async {
  return Map<String, Object?>.from(input! as Map);
}

class User {
  const User({required this.id, required this.name});

  final int id;
  final String name;

  static Future<User> parse(Object? input) async {
    return User.fromJson(Map<String, Object?>.from(input! as Map));
  }

  static Future<List<User>> parseList(Object? input) async {
    final items = input! as List<Object?>;
    return items.cast<Map<String, Object?>>().map(User.fromJson).toList();
  }

  factory User.fromJson(Map<String, Object?> json) {
    return User(id: json['id']! as int, name: json['name']! as String);
  }
}

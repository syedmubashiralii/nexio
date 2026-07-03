import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexio/nexio.dart';

void main() {
  test('resolves environments and parses typed models', () async {
    final adapter = _FakeAdapter((options) {
      expect(options.uri.toString(), 'https://dev.example.com/users');
      return ResponseBody.fromString(
        '[{"id":1,"name":"Ada"}]',
        200,
        headers: _jsonHeaders,
      );
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
    );

    final response = await Nexio.get<List<_User>>(
      '/users',
      parser: (input) async {
        final items = input! as List<Object?>;
        return items.cast<Map<String, Object?>>().map(_User.fromJson).toList();
      },
    );

    expect(response.data.single.name, 'Ada');
    expect(response.fromCache, isFalse);
    expect(response.metrics.totalDuration, isNot(Duration.zero));

    Nexio.switchEnvironment('production');
    expect(Nexio.resolveUrl('/users'), 'https://api.example.com/users');
  });

  test('retries transient status codes', () async {
    var attempts = 0;
    final adapter = _FakeAdapter((_) {
      attempts += 1;
      if (attempts < 3) {
        return ResponseBody.fromString('temporary', 500);
      }
      return ResponseBody.fromString('{"ok":true}', 200, headers: _jsonHeaders);
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      retryPolicy: const RetryPolicy(
        retries: 2,
        strategy: RetryStrategy.fixed,
        delay: Duration.zero,
      ),
    );

    final response = await Nexio.get<Map<String, Object?>>(
      '/status',
      parser: _mapParser,
    );

    expect(response.data['ok'], isTrue);
    expect(attempts, 3);
  });

  test('deduplicates identical in-flight requests', () async {
    var hits = 0;
    final adapter = _FakeAdapter((_) async {
      hits += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return ResponseBody.fromString('{"id":7}', 200, headers: _jsonHeaders);
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
    );

    final responses = await Future.wait([
      Nexio.get<Map<String, Object?>>('/profile', parser: _mapParser),
      Nexio.get<Map<String, Object?>>('/profile', parser: _mapParser),
      Nexio.get<Map<String, Object?>>('/profile', parser: _mapParser),
    ]);

    expect(hits, 1);
    expect(responses.map((response) => response.data['id']), [7, 7, 7]);
  });

  test('encrypts request payloads with AES-GCM envelopes', () async {
    Object? sentData;
    final adapter = _FakeAdapter((options) {
      sentData = options.data;
      return ResponseBody.fromString('{"ok":true}', 200, headers: _jsonHeaders);
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      encryptionConfig: const EncryptionConfig(
        aesGcmKey: '12345678901234567890123456789012',
      ),
    );

    final response = await Nexio.post<Map<String, Object?>>(
      '/payment',
      data: <String, Object?>{'amount': 10},
      encryptionMode: EncryptionMode.aesGcm,
      parser: _mapParser,
    );

    expect(response.data['ok'], isTrue);
    expect(sentData, isA<Map>());
    final envelope = sentData! as Map<Object?, Object?>;
    expect(envelope['nexioEncrypted'], isTrue);
    expect(envelope['mode'], 'aesGcm');
    expect(envelope['nonce'], isNotNull);
    expect(envelope['mac'], isNotNull);
    expect(envelope['payload'], isNotNull);
  });

  test('serves cache-only reads from memory cache', () async {
    var hits = 0;
    final adapter = _FakeAdapter((_) {
      hits += 1;
      return ResponseBody.fromString('{"cached":true}', 200,
          headers: _jsonHeaders);
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      cacheConfig: const CacheConfig(enableDiskCache: false),
    );

    final first = await Nexio.get<Map<String, Object?>>(
      '/cache',
      cachePolicy: CachePolicy.networkFirst,
      parser: _mapParser,
    );
    final second = await Nexio.get<Map<String, Object?>>(
      '/cache',
      cachePolicy: CachePolicy.cacheOnly,
      parser: _mapParser,
    );

    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
    expect(second.data['cached'], isTrue);
    expect(hits, 1);
  });

  test('coordinates one auth refresh and retries with dynamic headers',
      () async {
    var token = 'expired';
    var refreshCalls = 0;
    final paths = <String>[];

    final adapter = _FakeAdapter((options) async {
      paths.add(options.path);
      if (options.headers['Authorization'] != 'Bearer fresh') {
        return ResponseBody.fromString(
          '{"code":"TOKEN_EXPIRED"}',
          401,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        '{"ok":true,"path":"${options.path}"}',
        200,
        headers: _jsonHeaders,
      );
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      authConfig: NexioAuthConfig(
        headersProvider: () => <String, Object?>{
          'Authorization': 'Bearer $token',
        },
        refresh: (_) async {
          refreshCalls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          token = 'fresh';
          return true;
        },
      ),
    );

    final responses = await Future.wait([
      Nexio.get<Map<String, Object?>>('/balance', parser: _mapParser),
      Nexio.get<Map<String, Object?>>('/offers', parser: _mapParser),
    ]);

    expect(refreshCalls, 1);
    expect(responses.map((response) => response.data['ok']), [true, true]);
    expect(
        paths,
        containsAll(<String>[
          'https://dev.example.com/balance',
          'https://dev.example.com/offers',
        ]));
  });

  test('uses cache key extra to isolate versioned enterprise caches', () async {
    var hits = 0;
    final adapter = _FakeAdapter((_) {
      hits += 1;
      return ResponseBody.fromString(
        '{"version":$hits}',
        200,
        headers: _jsonHeaders,
      );
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      cacheConfig: const CacheConfig(enableDiskCache: false),
    );

    final versionOne = await Nexio.get<Map<String, Object?>>(
      '/dashboard',
      cachePolicy: CachePolicy.networkFirst,
      cacheKeyExtra: const {'apiVersion': 'v1', 'country': 'TZ'},
      parser: _mapParser,
    );
    final cachedVersionOne = await Nexio.get<Map<String, Object?>>(
      '/dashboard',
      cachePolicy: CachePolicy.cacheOnly,
      cacheKeyExtra: const {'apiVersion': 'v1', 'country': 'TZ'},
      parser: _mapParser,
    );

    expect(versionOne.data['version'], 1);
    expect(cachedVersionOne.fromCache, isTrue);
    expect(cachedVersionOne.data['version'], 1);

    await expectLater(
      Nexio.get<Map<String, Object?>>(
        '/dashboard',
        cachePolicy: CachePolicy.cacheOnly,
        cacheKeyExtra: const {'apiVersion': 'v2', 'country': 'TZ'},
        parser: _mapParser,
      ),
      throwsA(isA<NexioCacheMissException>()),
    );
  });

  test('supports arbitrary environments and interceptor-controlled requests',
      () async {
    var dioFactoryCalls = 0;
    final capturedChuckerFlags = <bool?>[];
    final capturedEnvironments = <String?>[];
    final hitsByEnvironment = <String, int>{};

    Nexio.initialize(
      environments: const <String, NexioEnvironment>{
        'qa-east': NexioEnvironment(
          baseUrl: 'https://qa-east.example.com',
          headers: <String, Object?>{'X-Region': 'east'},
        ),
        'preprod-africa': NexioEnvironment(
          baseUrl: 'https://preprod.example.com',
          headers: <String, Object?>{'X-Region': 'africa'},
        ),
      },
      initialEnvironment: 'qa-east',
      enableChucker: false,
      dioFactory: (name, environment) {
        dioFactoryCalls += 1;
        return _dio(
          _FakeAdapter((options) {
            hitsByEnvironment[name] = (hitsByEnvironment[name] ?? 0) + 1;
            expect(
                options.headers['X-Region'], environment.headers['X-Region']);
            return ResponseBody.fromString(
              '{"environment":"$name"}',
              200,
              headers: _jsonHeaders,
            );
          }),
        );
      },
      interceptorFactories: <NexioInterceptorFactory>[
        () => _CaptureMetadataInterceptor(
              chuckerFlags: capturedChuckerFlags,
              environments: capturedEnvironments,
            ),
      ],
    );

    await Nexio.get<Map<String, Object?>>(
      '/profile',
      logInChucker: true,
      parser: _mapParser,
    );
    await Nexio.get<Map<String, Object?>>(
      '/balance',
      logInChucker: false,
      parser: _mapParser,
    );

    Nexio.switchEnvironment('preprod-africa');
    final response = await Nexio.get<Map<String, Object?>>(
      '/profile',
      logInChucker: true,
      parser: _mapParser,
    );

    expect(response.data['environment'], 'preprod-africa');
    expect(dioFactoryCalls, 2);
    expect(hitsByEnvironment, <String, int>{
      'qa-east': 2,
      'preprod-africa': 1,
    });
    expect(capturedChuckerFlags, <bool?>[true, false, true]);
    expect(
      capturedEnvironments,
      <String?>['qa-east', 'qa-east', 'preprod-africa'],
    );
  });

  test('aggregates sanitized network health outcomes', () async {
    NexioHealthSnapshot? flushed;
    final adapter = _FakeAdapter((options) {
      if (options.path.endsWith('/failure')) {
        return ResponseBody.fromString(
          '{"error":true}',
          500,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString('{"ok":true}', 200, headers: _jsonHeaders);
    });

    Nexio.initialize(
      environments: _environments,
      initialEnvironment: 'dev',
      dio: _dio(adapter),
      healthConfig: NexioHealthConfig(
        flushEveryRequests: 100,
        onFlush: (snapshot) => flushed = snapshot,
      ),
    );

    await Nexio.get<Map<String, Object?>>('/ok?secret=hidden',
        parser: _mapParser);
    await expectLater(
      Nexio.get<Map<String, Object?>>('/failure', parser: _mapParser),
      throwsA(isA<NexioHttpException<Map<String, Object?>>>()),
    );

    final current = Nexio.healthSnapshot;
    expect(current.counts['/ok']?[NexioHealthOutcome.ok], 1);
    expect(
      current.counts['/failure']?[NexioHealthOutcome.serverError],
      1,
    );
    expect(current.counts.keys.any((key) => key.contains('secret')), isFalse);

    await Nexio.flushHealth();
    expect(flushed?.total, 2);
  });
}

const _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const _environments = <String, NexioEnvironment>{
  'test': NexioEnvironment(baseUrl: 'https://test.example.com'),
  'dev': NexioEnvironment(baseUrl: 'https://dev.example.com'),
  'staging': NexioEnvironment(baseUrl: 'https://staging.example.com'),
  'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
};

Dio _dio(HttpClientAdapter adapter) {
  return Dio()..httpClientAdapter = adapter;
}

Future<Map<String, Object?>> _mapParser(Object? input) async {
  return Map<String, Object?>.from(input! as Map);
}

class _User {
  const _User({required this.id, required this.name});

  final int id;
  final String name;

  factory _User.fromJson(Map<String, Object?> json) {
    return _User(
      id: json['id']! as int,
      name: json['name']! as String,
    );
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _CaptureMetadataInterceptor extends Interceptor {
  _CaptureMetadataInterceptor({
    required this.chuckerFlags,
    required this.environments,
  });

  final List<bool?> chuckerFlags;
  final List<String?> environments;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    chuckerFlags.add(
      options.extra[NexioRequestMetadata.logInChucker] as bool?,
    );
    environments.add(
      options.extra[NexioRequestMetadata.environmentName] as String?,
    );
    handler.next(options);
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nexio/nexio.dart';

/// App-owned token refresh operation, usually implemented with a dedicated Dio.
typedef RefreshSession = Future<SessionTokens?> Function(
  NexioAuthSignal signal,
);

/// Enterprise-style setup for fintech, telecom, wallet, and self-care apps.
class FintechTelecomRuntime {
  FintechTelecomRuntime({
    required this.sessionStore,
    required this.deviceContext,
    required this.remoteConfig,
    required this.refreshSession,
    required this.connectivityProbe,
  });

  final SessionStore sessionStore;
  final DeviceContext deviceContext;
  final RemoteConfigStore remoteConfig;
  final RefreshSession refreshSession;
  final NexioConnectivityProbe connectivityProbe;

  /// Initialize once from `main.dart`.
  void initialize() {
    Nexio.initialize(
      environments: const {
        'test': NexioEnvironment(baseUrl: 'https://test-gateway.example.com'),
        'dev': NexioEnvironment(baseUrl: 'https://dev-gateway.example.com'),
        'staging': NexioEnvironment(
          baseUrl: 'https://staging-gateway.example.com',
        ),
        'production': NexioEnvironment(baseUrl: 'https://gateway.example.com'),
      },
      initialEnvironment: 'dev',
      loggerEnabled: true,
      enableChucker: true,
      defaultLogInChucker: false,
      defaultThreadMode: ThreadMode.auto,
      parseThresholdKb: 64,
      maxConcurrentRequests: 6,
      networkConfig: NexioNetworkConfig(
        connectivityProbe: connectivityProbe,
      ),
      retryPolicy: const RetryPolicy(
        retries: 2,
        strategy: RetryStrategy.exponential,
        delay: Duration(milliseconds: 250),
      ),
      cacheConfig: const CacheConfig(
        defaultTtl: Duration(minutes: 15),
        enableMemoryCache: true,
        enableDiskCache: true,
      ),
      authConfig: NexioAuthConfig(
        headersProvider: _headers,
        decide: _authDecision,
        refresh: _refreshTokens,
        onSessionExpired: (_) => sessionStore.markSessionExpired(),
      ),
    );

    Nexio.registerParser<AccountBalance>(AccountBalance.parse);
    Nexio.registerParser<List<Offer>>(Offer.parseList);
    Nexio.registerParser<PaymentReceipt>(PaymentReceipt.parse);
  }

  Map<String, Object?> _headers() {
    return <String, Object?>{
      Headers.contentTypeHeader: Headers.jsonContentType,
      'Accept': Headers.jsonContentType,
      'Authorization': 'Bearer ${sessionStore.accessToken}',
      'X-Gateway-Token': sessionStore.gatewayToken,
      'X-Device-Id': deviceContext.deviceId,
      'X-App-Version': deviceContext.appVersion,
      'X-Language': deviceContext.languageCode,
      'X-Country': deviceContext.countryCode,
      'X-Channel': 'flutter-self-care',
    };
  }

  NexioAuthDecision _authDecision(NexioAuthSignal signal) {
    final data = signal.data;

    if (signal.statusCode == 401) {
      return NexioAuthDecision.refreshAndRetry;
    }

    if (data is Map) {
      final responseCode = data['responseCode']?.toString();
      final gatewayCode = data['gatewayCode']?.toString();

      if (responseCode == '410' || gatewayCode == '900901') {
        return NexioAuthDecision.refreshAndRetry;
      }
      if (responseCode == '411' || responseCode == '423') {
        return NexioAuthDecision.expireSession;
      }
    }

    return NexioAuthDecision.proceed;
  }

  Future<bool> _refreshTokens(NexioAuthSignal signal) async {
    final tokens = await refreshSession(signal);
    if (tokens == null) {
      return false;
    }

    sessionStore.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      gatewayToken: tokens.gatewayToken,
    );
    return true;
  }

  /// High-frequency balance call: deduped, fast, typed, and no global dialog.
  Future<AccountBalance> fetchBalance() async {
    final response = await Nexio.get<AccountBalance>(
      '/wallet/balance',
      showLoader: false,
      cachePolicy: CachePolicy.networkFirst,
      cacheTtl: const Duration(seconds: 30),
      cacheKeyExtra: _cacheNamespace('balance'),
      priority: RequestPriority.high,
      cancelTag: 'balance',
      logInChucker: true,
    );
    return response.data;
  }

  /// Dashboard offers: cache by remote-config API version and parse large JSON
  /// away from the main isolate when the response crosses the threshold.
  Future<List<Offer>> fetchDashboardOffers() async {
    final response = await Nexio.get<List<Offer>>(
      '/dashboard/offers',
      cachePolicy: CachePolicy.cacheFirst,
      cacheTtl: const Duration(hours: 4),
      cacheKeyExtra: _cacheNamespace('dashboardOffers'),
      threadMode: ThreadMode.auto,
      parseThresholdKb: 32,
      isolateParser: Offer.parseListInIsolate,
      priority: RequestPriority.normal,
      logInChucker: true,
    );
    return response.data;
  }

  /// Transaction call: encrypted, high priority, not deduped unless the app has
  /// a transaction idempotency key and wants shared responses.
  Future<PaymentReceipt> payMerchant({
    required String merchantId,
    required int amountMinor,
    required String idempotencyKey,
  }) async {
    final response = await Nexio.post<PaymentReceipt>(
      '/payments/merchant',
      data: <String, Object?>{
        'merchantId': merchantId,
        'amountMinor': amountMinor,
        'idempotencyKey': idempotencyKey,
        ...deviceContext.commonBody(),
      },
      headers: <String, Object?>{'X-Idempotency-Key': idempotencyKey},
      encryptionMode: EncryptionMode.aesGcm,
      retryPolicy: const RetryPolicy(retries: 0),
      priority: RequestPriority.high,
      deduplicate: false,
      cancelGroup: 'payments',
      showLoader: true,
      logInChucker: false,
    );
    return response.data;
  }

  /// Upload KYC documents with progress and cancellation support.
  Future<Map<String, Object?>> uploadKycDocument({
    required String path,
    required void Function(int sent, int total) onProgress,
  }) async {
    final response = await Nexio.upload<Map<String, Object?>>(
      '/kyc/documents',
      files: [
        NexioUploadFile(
          fieldName: 'document',
          path: path,
          contentType: 'application/pdf',
        ),
      ],
      fields: deviceContext.commonBody(),
      cancelTag: 'kyc-upload',
      onSendProgress: onProgress,
      logInChucker: false,
      parser: parseMap,
    );
    return response.data;
  }

  /// Store locator: page owns the visible loader before GPS work begins; Nexio
  /// runs the API call in background mode so the dialog does not appear late.
  Future<Map<String, Object?>> fetchStores({
    required String latitude,
    required String longitude,
  }) async {
    final response = await Nexio.get<Map<String, Object?>>(
      '/stores',
      queryParameters: <String, Object?>{'lat': latitude, 'lng': longitude},
      showLoader: false,
      cachePolicy: CachePolicy.networkFirst,
      cacheTtl: const Duration(minutes: 5),
      parser: parseMap,
    );
    return response.data;
  }

  Object _cacheNamespace(String apiName) {
    return <String, Object?>{
      'api': apiName,
      'version': remoteConfig.versionFor(apiName),
      'country': deviceContext.countryCode,
      'language': deviceContext.languageCode,
      'msisdn': sessionStore.msisdn,
    };
  }
}

class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.gatewayToken,
  });

  final String accessToken;
  final String refreshToken;
  final String gatewayToken;
}

Future<Map<String, Object?>> parseMap(Object? input) async {
  return Map<String, Object?>.from(input! as Map);
}

class SessionStore {
  String accessToken = '';
  String refreshToken = '';
  String gatewayToken = '';
  String msisdn = '';

  void saveTokens({
    required String accessToken,
    required String refreshToken,
    required String gatewayToken,
  }) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.gatewayToken = gatewayToken;
  }

  void markSessionExpired() {
    debugPrint('Redirect user to login once.');
  }
}

class DeviceContext {
  const DeviceContext({
    required this.deviceId,
    required this.appVersion,
    required this.languageCode,
    required this.countryCode,
  });

  final String deviceId;
  final String appVersion;
  final String languageCode;
  final String countryCode;

  Map<String, Object?> commonBody() {
    return <String, Object?>{
      'deviceId': deviceId,
      'appVersion': appVersion,
      'languageCode': languageCode,
      'countryCode': countryCode,
      'channel': 'flutter-self-care',
    };
  }
}

class RemoteConfigStore {
  const RemoteConfigStore(this.versions);

  final Map<String, String> versions;

  String versionFor(String apiName) => versions[apiName] ?? '1';
}

class AccountBalance {
  const AccountBalance({required this.amountMinor, required this.currency});

  final int amountMinor;
  final String currency;

  static Future<AccountBalance> parse(Object? input) async {
    final json = Map<String, Object?>.from(input! as Map);
    return AccountBalance(
      amountMinor: json['amountMinor']! as int,
      currency: json['currency']! as String,
    );
  }
}

class Offer {
  const Offer({required this.id, required this.title});

  final String id;
  final String title;

  static Future<List<Offer>> parseList(Object? input) async {
    final items = input! as List<Object?>;
    return items.map((item) {
      final json = Map<String, Object?>.from(item! as Map);
      return Offer(
        id: json['id']!.toString(),
        title: json['title']!.toString(),
      );
    }).toList();
  }

  static List<Offer> parseListInIsolate(String source) {
    final decoded = jsonDecode(source) as List<Object?>;
    return decoded.map((item) {
      final json = Map<String, Object?>.from(item! as Map);
      return Offer(
        id: json['id']!.toString(),
        title: json['title']!.toString(),
      );
    }).toList();
  }
}

class PaymentReceipt {
  const PaymentReceipt({required this.transactionId, required this.status});

  final String transactionId;
  final String status;

  static Future<PaymentReceipt> parse(Object? input) async {
    final json = Map<String, Object?>.from(input! as Map);
    return PaymentReceipt(
      transactionId: json['transactionId']!.toString(),
      status: json['status']!.toString(),
    );
  }
}

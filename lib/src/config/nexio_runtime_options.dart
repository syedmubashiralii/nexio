import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../auth/nexio_auth_config.dart';
import '../cache/cache_config.dart';
import '../events/nexio_events.dart';
import '../interceptors/nexio_interceptor.dart';
import '../monitoring/nexio_health_monitor.dart';
import 'encryption_config.dart';
import 'environment.dart';
import 'retry_policy.dart';

/// Global options used when Nexio is initialized.
class NexioRuntimeOptions {
  /// Creates global runtime options.
  ///
  /// Parameters:
  /// - [environments] maps arbitrary user-defined names to configurations.
  /// - [initialEnvironment] is the active environment name after initialization.
  /// - [encryptionConfig] supplies built-in AES secrets. Defaults to no secrets.
  /// - [defaultEncryptionMode] is used when a request does not override
  ///   encryption. Defaults to [EncryptionMode.none].
  /// - [loggerEnabled] enables console and in-memory logs. Defaults to `false`.
  /// - [enableChucker] adds Chucker's Dio interceptor. Defaults to `false`.
  /// - [defaultLogInChucker] is the per-request Chucker default. Defaults to
  ///   `false`, so sensitive traffic is captured only when explicitly enabled.
  /// - [interceptorFactories] creates user interceptors for every cached Dio.
  /// - [retryPolicy] is the global retry policy. Defaults to no retries.
  /// - [cacheConfig] controls memory and disk cache behavior.
  /// - [defaultThreadMode] controls default parsing placement.
  /// - [parseThresholdKb] is the `ThreadMode.auto` threshold. Defaults to 64 KB.
  /// - [offlineQueueEnabled] stores no-connectivity failures for replay.
  ///   Defaults to `false`.
  /// - [healthConfig] controls low-cardinality network health aggregation.
  /// - [maxConcurrentRequests] caps the scheduler. Defaults to `6`.
  /// - [defaultHeaders] are added to every request unless overridden.
  /// - [authConfig] supplies dynamic auth headers and backend-agnostic
  ///   refresh/session coordination. Defaults to `null`.
  /// - [navigatorKey] lets Nexio show loaders without a per-request context.
  /// - [dio] injects a custom Dio instance, mainly for tests or custom adapters.
  /// - [dioFactory] creates a Dio per named environment for custom adapters,
  ///   certificate pinning, proxies, or transport testing.
  /// - [onUnauthorized] is called for HTTP 401 responses; token refresh remains
  ///   application-owned.
  const NexioRuntimeOptions({
    required this.environments,
    required this.initialEnvironment,
    this.encryptionConfig = const EncryptionConfig(),
    this.defaultEncryptionMode = EncryptionMode.none,
    this.loggerEnabled = false,
    this.enableChucker = false,
    this.defaultLogInChucker = false,
    this.interceptorFactories = const <NexioInterceptorFactory>[],
    this.retryPolicy = RetryPolicy.none,
    this.cacheConfig = const CacheConfig(),
    this.defaultThreadMode = ThreadMode.auto,
    this.parseThresholdKb = 64,
    this.offlineQueueEnabled = false,
    this.healthConfig = const NexioHealthConfig(),
    this.maxConcurrentRequests = 6,
    this.defaultHeaders = const {},
    this.authConfig,
    this.navigatorKey,
    this.dio,
    this.dioFactory,
    this.onUnauthorized,
  });

  /// Base URLs keyed by environment.
  final Map<String, NexioEnvironment> environments;

  /// Environment selected during initialization.
  final String initialEnvironment;

  /// Built-in encryption configuration.
  final EncryptionConfig encryptionConfig;

  /// Default encryption mode used by requests.
  final EncryptionMode defaultEncryptionMode;

  /// Whether request and response logs are collected.
  final bool loggerEnabled;

  /// Whether Chucker's Dio interceptor is installed.
  final bool enableChucker;

  /// Whether requests are captured in Chucker when they do not override it.
  final bool defaultLogInChucker;

  /// Factories for app-owned interceptors installed on each cached Dio.
  final List<NexioInterceptorFactory> interceptorFactories;

  /// Global retry policy used when a request does not override it.
  final RetryPolicy retryPolicy;

  /// Global cache configuration.
  final CacheConfig cacheConfig;

  /// Default parser thread mode.
  final ThreadMode defaultThreadMode;

  /// Payload size threshold, in kilobytes, for background parsing in auto mode.
  final int parseThresholdKb;

  /// Whether no-connectivity failures are stored and replayed later.
  final bool offlineQueueEnabled;

  /// Aggregated network health configuration.
  final NexioHealthConfig healthConfig;

  /// Maximum number of network requests running at once.
  final int maxConcurrentRequests;

  /// Headers applied to every request unless overridden.
  final Map<String, Object?> defaultHeaders;

  /// Auth/session coordination configuration.
  final NexioAuthConfig? authConfig;

  /// Navigator key used for global loader presentation.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Optional custom Dio instance.
  final Dio? dio;

  /// Optional factory for environment-specific Dio instances.
  final Dio Function(String name, NexioEnvironment environment)? dioFactory;

  /// Hook called when a response has HTTP 401 status.
  final void Function(NexioUnauthorizedEvent event)? onUnauthorized;
}

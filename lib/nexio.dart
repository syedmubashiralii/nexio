/// Nexio is a production-grade networking runtime for Flutter.
///
/// The package uses Dio internally and adds environment switching, encryption,
/// retries, parsing, cancellation, logging, caching, offline queuing, uploads,
/// downloads, and lifecycle events behind a compact API.
library;

export 'package:chucker_flutter/chucker_flutter.dart'
    show ChuckerFlutter, ChuckerDioInterceptor;
export 'package:dio/dio.dart'
    show
        CancelToken,
        Dio,
        DioException,
        DioExceptionType,
        FormData,
        Headers,
        MultipartFile,
        Options,
        ProgressCallback,
        ResponseType;
export 'package:flutter/widgets.dart'
    show BuildContext, Color, GlobalKey, NavigatorState, Widget;
export 'package:xml/xml.dart' show XmlDocument;

export 'src/auth/nexio_auth_config.dart';
export 'src/cache/cache_config.dart';
export 'src/cache/cache_store.dart' show NexioCacheEntry;
export 'src/cancellation/cancellation_registry.dart' show NexioCancelHandle;
export 'src/config/encryption_config.dart';
export 'src/config/environment.dart';
export 'src/config/nexio_request_options.dart';
export 'src/config/nexio_runtime_options.dart';
export 'src/config/retry_policy.dart';
export 'src/encryption/encryption_engine.dart'
    show NexioCipher, NexioEncryptionAdapter;
export 'src/errors/nexio_exception.dart';
export 'src/events/nexio_events.dart';
export 'src/interceptors/nexio_interceptor.dart';
export 'src/loader/nexio_loader.dart';
export 'src/models/nexio_metrics.dart';
export 'src/models/nexio_response.dart';
export 'src/monitoring/nexio_health_monitor.dart';
export 'src/network/network_config.dart';
export 'src/nexio_facade.dart';
export 'src/parser/nexio_parser.dart';
export 'src/transfers/nexio_download.dart';
export 'src/transfers/nexio_upload.dart';

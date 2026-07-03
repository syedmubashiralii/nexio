import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';

import 'nexio_interceptor.dart';

/// Delegates to Chucker only when a request opts into capture.
class NexioConditionalChuckerInterceptor extends Interceptor {
  final ChuckerDioInterceptor _delegate = ChuckerDioInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isEnabled(options)) {
      _delegate.onRequest(options, handler);
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_isEnabled(response.requestOptions)) {
      _delegate.onResponse(response, handler);
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isEnabled(err.requestOptions)) {
      _delegate.onError(err, handler);
      return;
    }
    handler.next(err);
  }

  bool _isEnabled(RequestOptions options) {
    return options.extra[NexioRequestMetadata.logInChucker] == true;
  }
}

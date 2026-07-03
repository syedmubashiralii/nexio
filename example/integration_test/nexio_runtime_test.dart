import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexio/nexio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switches environments and parses JSON in a background isolate', (
    tester,
  ) async {
    final requestedUrls = <String>[];

    Nexio.initialize(
      environments: const <String, NexioEnvironment>{
        'qa': NexioEnvironment(baseUrl: 'https://qa.example.com'),
        'production': NexioEnvironment(baseUrl: 'https://api.example.com'),
      },
      initialEnvironment: 'qa',
      dioFactory: (_, __) =>
          Dio()..httpClientAdapter = _IntegrationAdapter(requestedUrls),
    );

    final qa = await Nexio.get<List<int>>(
      '/large-payload',
      threadMode: ThreadMode.background,
      parser: _parseIds,
    );

    Nexio.switchEnvironment('production');
    final production = await Nexio.get<List<int>>(
      '/large-payload',
      threadMode: ThreadMode.background,
      parser: _parseIds,
    );

    expect(qa.data, <int>[1, 2, 3]);
    expect(production.data, <int>[1, 2, 3]);
    expect(requestedUrls, <String>[
      'https://qa.example.com/large-payload',
      'https://api.example.com/large-payload',
    ]);
  });
}

Future<List<int>> _parseIds(Object? input) async {
  return (input! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map((item) => item['id']! as int)
      .toList();
}

class _IntegrationAdapter implements HttpClientAdapter {
  _IntegrationAdapter(this.requestedUrls);

  final List<String> requestedUrls;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    return ResponseBody.fromString(
      '[{"id":1},{"id":2},{"id":3}]',
      200,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

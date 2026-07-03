import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Current state of a Nexio download task.
enum NexioDownloadState {
  /// The task has not started yet.
  idle,

  /// The task is actively downloading.
  running,

  /// The task was paused and may be resumed.
  paused,

  /// The task completed successfully.
  completed,

  /// The task was cancelled permanently.
  cancelled,

  /// The task failed.
  failed,
}

/// A pause, resume, and cancel capable download task.
class NexioDownloadTask {
  /// Creates a download task.
  ///
  /// Parameters:
  /// - [dio] is the Dio instance used to download.
  /// - [url] is the resolved absolute URL.
  /// - [destinationPath] is the local file destination.
  /// - [queryParameters] are request query parameters.
  /// - [options] are Dio request options.
  /// - [onProgress] receives download progress.
  /// - [autoStart] starts the task immediately. Defaults to `true`.
  NexioDownloadTask({
    required Dio dio,
    required String url,
    required String destinationPath,
    Map<String, Object?>? queryParameters,
    Options? options,
    ProgressCallback? onProgress,
    bool autoStart = true,
  })  : _dio = dio,
        _url = url,
        _destinationPath = destinationPath,
        _queryParameters = queryParameters,
        _options = options,
        _onProgress = onProgress {
    if (autoStart) {
      unawaited(start());
    }
  }

  final Dio _dio;
  final String _url;
  final String _destinationPath;
  final Map<String, Object?>? _queryParameters;
  final Options? _options;
  final ProgressCallback? _onProgress;
  final Completer<String> _completed = Completer<String>();
  CancelToken _cancelToken = CancelToken();
  NexioDownloadState _state = NexioDownloadState.idle;
  int _receivedBytes = 0;

  /// Current task state.
  NexioDownloadState get state => _state;

  /// Destination file path.
  String get destinationPath => _destinationPath;

  /// Completes with [destinationPath] when the download finishes.
  Future<String> get completed => _completed.future;

  /// Starts the download from the beginning.
  Future<void> start() => _run(resume: false);

  /// Pauses the current download.
  Future<void> pause() async {
    if (_state != NexioDownloadState.running) {
      return;
    }
    _state = NexioDownloadState.paused;
    _cancelToken.cancel('Paused by NexioDownloadTask');
  }

  /// Resumes a paused download using HTTP range requests.
  Future<void> resume() => _run(resume: true);

  /// Cancels the current download permanently.
  void cancel() {
    if (_state == NexioDownloadState.completed ||
        _state == NexioDownloadState.cancelled) {
      return;
    }
    _state = NexioDownloadState.cancelled;
    _cancelToken.cancel('Cancelled by NexioDownloadTask');
    if (!_completed.isCompleted) {
      _completed.completeError(StateError('Download cancelled.'));
    }
  }

  Future<void> _run({required bool resume}) async {
    if (_state == NexioDownloadState.running ||
        _state == NexioDownloadState.completed ||
        _state == NexioDownloadState.cancelled) {
      return;
    }
    _state = NexioDownloadState.running;
    _cancelToken = CancelToken();

    final file = File(_destinationPath);
    final canResume = resume && file.existsSync();
    _receivedBytes = canResume ? file.lengthSync() : 0;
    final headers = <String, Object?>{
      ...?_options?.headers,
      if (canResume && _receivedBytes > 0) 'range': 'bytes=$_receivedBytes-',
    };

    try {
      await _dio.download(
        _url,
        _destinationPath,
        queryParameters: _queryParameters,
        cancelToken: _cancelToken,
        deleteOnError: false,
        fileAccessMode:
            canResume ? FileAccessMode.append : FileAccessMode.write,
        options: (_options ?? Options()).copyWith(headers: headers),
        onReceiveProgress: (received, total) {
          final adjustedReceived = _receivedBytes + received;
          final adjustedTotal = total <= 0 ? total : _receivedBytes + total;
          _onProgress?.call(adjustedReceived, adjustedTotal);
        },
      );
      _state = NexioDownloadState.completed;
      if (!_completed.isCompleted) {
        _completed.complete(_destinationPath);
      }
    } on DioException catch (error, stackTrace) {
      if (_state == NexioDownloadState.paused) {
        return;
      }
      _state = NexioDownloadState.failed;
      if (!_completed.isCompleted) {
        _completed.completeError(error, stackTrace);
      }
    } catch (error, stackTrace) {
      _state = NexioDownloadState.failed;
      if (!_completed.isCompleted) {
        _completed.completeError(error, stackTrace);
      }
    }
  }
}

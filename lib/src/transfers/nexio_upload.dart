import 'package:dio/dio.dart';

/// File descriptor used by Nexio multipart uploads.
class NexioUploadFile {
  /// Creates an upload file descriptor.
  ///
  /// Parameters:
  /// - [fieldName] is the multipart field name expected by the API.
  /// - [path] is the local file path.
  /// - [filename] overrides the uploaded filename. Defaults to Dio's filename.
  /// - [contentType] is an optional media type such as `image/png`.
  const NexioUploadFile({
    required this.fieldName,
    required this.path,
    this.filename,
    this.contentType,
  });

  /// Multipart field name.
  final String fieldName;

  /// Local file path.
  final String path;

  /// Uploaded filename override.
  final String? filename;

  /// Optional content type string.
  final String? contentType;

  /// Converts this descriptor to a Dio multipart file.
  Future<MapEntry<String, MultipartFile>> toMultipartEntry() async {
    return MapEntry<String, MultipartFile>(
      fieldName,
      await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType:
            contentType == null ? null : DioMediaType.parse(contentType!),
      ),
    );
  }
}

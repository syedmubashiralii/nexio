/// Runtime cache configuration for memory and disk storage.
class CacheConfig {
  /// Creates cache configuration.
  ///
  /// Parameters:
  /// - [enabled] turns cache reads and writes on globally. Defaults to `true`;
  ///   request-level [CachePolicy.networkOnly] still avoids cache usage.
  /// - [enableMemoryCache] stores valid entries in memory for fast reuse.
  ///   Defaults to `true`.
  /// - [enableDiskCache] stores JSON, text, and byte responses on disk.
  ///   Defaults to `true`.
  /// - [defaultTtl] is the time-to-live used when a request does not provide a
  ///   cache TTL. Defaults to five minutes.
  /// - [maxMemoryEntries] caps in-memory entries before the oldest entries are
  ///   evicted. Defaults to `128`.
  /// - [diskFolderName] is the folder name under the app support directory.
  ///   Defaults to `nexio_cache`.
  const CacheConfig({
    this.enabled = true,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.defaultTtl = const Duration(minutes: 5),
    this.maxMemoryEntries = 128,
    this.diskFolderName = 'nexio_cache',
  });

  /// Whether cache reads and writes are enabled globally.
  final bool enabled;

  /// Whether valid cache entries are retained in memory.
  final bool enableMemoryCache;

  /// Whether cache entries are persisted to disk.
  final bool enableDiskCache;

  /// Default cache time-to-live when a request does not provide one.
  final Duration defaultTtl;

  /// Maximum number of entries retained in memory.
  final int maxMemoryEntries;

  /// Folder name used for disk cache files.
  final String diskFolderName;
}

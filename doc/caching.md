# Caching Guide

Nexio supports memory cache, disk cache, TTL expiration, and four cache policies.

```dart
Nexio.initialize(
  environments: environments,
  initialEnvironment: 'production',
  cacheConfig: const CacheConfig(
    enableMemoryCache: true,
    enableDiskCache: true,
    defaultTtl: Duration(minutes: 5),
  ),
);
```

Disk entries contain decrypted response data in the application support
directory. Use `networkOnly` for sensitive responses unless the application
provides an appropriate encrypted storage layer.

Policies:

- `CachePolicy.networkOnly`: never reads cache.
- `CachePolicy.cacheOnly`: reads cache and fails on miss.
- `CachePolicy.cacheFirst`: returns cache first, then network.
- `CachePolicy.networkFirst`: tries network, falls back to cache.

Example:

```dart
final response = await Nexio.get<List<Article>>(
  '/articles',
  cachePolicy: CachePolicy.cacheFirst,
  cacheTtl: const Duration(minutes: 15),
  cacheKeyExtra: {
    'apiVersion': articlesVersion,
    'locale': locale,
  },
  parser: articleListParser,
);
```

Clear cache:

```dart
await Nexio.clearCache();
```

Include every value that changes response meaning in `cacheKeyExtra`, such as
API version, tenant, country, language, or signed-in account.

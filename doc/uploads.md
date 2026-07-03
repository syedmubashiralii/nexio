# Uploads Guide

Nexio uploads files through Dio multipart requests.

```dart
final response = await Nexio.upload<Map<String, Object?>>(
  '/uploads',
  files: const [
    NexioUploadFile(
      fieldName: 'image',
      path: '/storage/emulated/0/DCIM/avatar.jpg',
      contentType: 'image/jpeg',
    ),
  ],
  fields: const {'folder': 'avatars'},
  onSendProgress: (sent, total) {
    print('$sent / $total');
  },
  parser: (input) async => Map<String, Object?>.from(input! as Map),
);
```

Use `CancelToken`, `cancelTag`, or `cancelGroup` when uploads need cancellation:

```dart
final upload = Nexio.upload<void>(
  '/videos',
  files: videoFiles,
  cancelTag: 'video-upload',
);

Nexio.cancelTag('video-upload');
await upload;
```

Built-in request encryption does not accept multipart `FormData`. Encrypt files
before upload or use an app-owned upload contract when encrypted media is
required. Keep sensitive uploads out of Chucker with `logInChucker: false`.

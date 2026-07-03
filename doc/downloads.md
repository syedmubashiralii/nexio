# Downloads Guide

Nexio download tasks support progress, pause, resume, and cancel.

The application chooses a writable destination path and owns storage
permissions, free-space checks, and user-visible recovery.

```dart
final task = Nexio.download(
  '/reports/monthly.pdf',
  destinationPath: '/storage/emulated/0/Download/monthly.pdf',
  onProgress: (received, total) {
    print('$received / $total');
  },
);

await task.pause();
await task.resume();

final path = await task.completed;
```

Resume uses HTTP range requests and Dio append mode. Servers must support range
requests for resume to continue from the previous byte offset.

Cancel permanently when the owner is disposed:

```dart
task.cancel();
```

Set `logInChucker: false` for sensitive document URLs.

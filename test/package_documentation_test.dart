import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _releaseVersion = '0.1.0';

void main() {
  test('release version is consistent across public package files', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final readme = File('README.md').readAsStringSync();

    expect(pubspec, contains('version: $_releaseVersion'));
    expect(changelog, contains('## $_releaseVersion'));
    expect(readme, contains('nexio: ^$_releaseVersion'));
  });

  test('required adoption guides are present', () {
    const requiredFiles = <String>[
      'CONTRIBUTING.md',
      'SECURITY.md',
      'example/example.md',
      'doc/authentication.md',
      'doc/security.md',
      'doc/errors.md',
      'doc/offline-queue.md',
      'doc/fintech-telecom.md',
      'doc/testing.md',
      'doc/troubleshooting.md',
      'doc/production-checklist.md',
      'doc/publishing.md',
    ];

    for (final path in requiredFiles) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
    }
  });

  test('public Markdown relative links resolve to package files', () {
    final markdownLink = RegExp(r'\[[^\]]+\]\(([^)]+)\)');
    final missingTargets = <String>[];

    for (final source in _publicMarkdownFiles()) {
      final markdown = source.readAsStringSync();
      for (final match in markdownLink.allMatches(markdown)) {
        final target = match.group(1)!;
        if (_isExternalOrAnchor(target)) {
          continue;
        }

        final relativePath = Uri.decodeComponent(target.split('#').first);
        final targetPath = '${source.parent.path}/$relativePath';
        if (relativePath.isNotEmpty &&
            !FileSystemEntity.isFileSync(targetPath) &&
            !FileSystemEntity.isDirectorySync(targetPath)) {
          missingTargets.add('${source.path} -> $target');
        }
      }
    }

    expect(missingTargets, isEmpty, reason: 'Broken links: $missingTargets');
  });
}

Iterable<File> _publicMarkdownFiles() sync* {
  yield File('README.md');
  yield File('CONTRIBUTING.md');
  yield File('SECURITY.md');
  yield* Directory('doc')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.md'));
  yield File('example/example.md');
  yield File('example/README.md');
}

bool _isExternalOrAnchor(String target) {
  return target.startsWith('#') ||
      target.startsWith('https://') ||
      target.startsWith('http://') ||
      target.startsWith('mailto:');
}

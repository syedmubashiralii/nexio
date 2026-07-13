# Publishing Nexio to pub.dev

This guide prepares and publishes Nexio `0.2.0`. Published versions are
immutable, so complete every preflight step before confirming the upload.

The authoritative references are Dart's
[publishing guide](https://dart.dev/tools/pub/publishing),
[package layout](https://dart.dev/tools/pub/package-layout), and
[pub points](https://pub.dev/help/scoring) documentation.

## 1. Verify the Source Repository

The repository URL must remain reachable before every release. Verify the local
remote and public endpoint:

```bash
cd /path/to/nexio
git remote get-url origin
curl -I https://github.com/syedmubashiralii/nexio
```

`pubspec.yaml` must contain these valid destinations:

```yaml
repository: https://github.com/syedmubashiralii/nexio
issue_tracker: https://github.com/syedmubashiralii/nexio/issues
```

Do not publish with a placeholder or 404 URL. Commit and push the verified
release state before uploading it to pub.dev:

```bash
git add .
git commit -m "release: prepare nexio 0.2.0"
git push origin main
```

## 2. Verify Release Metadata

Confirm:

- package name is available on pub.dev;
- `version: 0.2.0` appears in `pubspec.yaml`;
- `CHANGELOG.md` starts with `## 0.2.0`;
- README installation uses `nexio: ^0.2.0`;
- homepage, repository, and issue tracker use valid HTTPS URLs;
- `LICENSE` contains the MIT license and correct copyright owner;
- Android and iOS are the declared V1 platforms.

Check package-name availability:

```bash
curl -I https://pub.dev/packages/nexio
```

A 404 response means no package page currently exists; it does not reserve the
name. A package page already owned by another publisher means a different
package name is required. The name is secured only after successful publication.

## 3. Run Package Preflight

From the package root:

```bash
cd /path/to/nexio
dart format --output=none --set-exit-if-changed lib test example
flutter analyze
flutter test
dart doc --output /tmp/nexio-api-docs
flutter pub outdated
flutter pub publish --dry-run
```

The dry run must list only intended files and finish with zero warnings.

## 4. Verify the Example Host

```bash
cd /path/to/nexio/example
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
flutter devices
flutter test integration_test/nexio_runtime_test.dart -d <device-id>
```

If no Android/iOS device or simulator is available, record that limitation. A
successful build is useful evidence but does not prove the integration test ran.

## 5. Estimate Pub Points with `pana`

Pub.dev currently reports a maximum of 160 pub points. The scoring model can
change, and the server calculation after upload is authoritative.

The official scoring guidance warns that `pana` can modify the analyzed
package. Run it on a temporary copy:

```bash
cd /path/to/nexio
PANA_DIR="$(mktemp -d /tmp/nexio-pana.XXXXXX)"
cp -R . "$PANA_DIR/nexio"
dart pub global activate pana
dart pub global run pana "$PANA_DIR/nexio"
```

Review every category:

- package conventions and valid release files;
- illustrative example and public API documentation;
- accurate platform support;
- static analysis and formatting;
- current Flutter/Dart compatibility;
- compatible up-to-date direct dependencies.

Fix every reproducible deduction, then rerun `pana` on a fresh temporary copy.
Do not write “160/160” in package marketing until pub.dev awards it.

## 6. Publish the First Version

Return to the package root and run:

```bash
cd /path/to/nexio
flutter pub publish --dry-run
flutter pub publish
```

The publish command opens the authentication flow when required, prints the
archive contents, and asks for final confirmation. Read the file list before
entering `y`.

After upload:

1. Open the package page.
2. Check README, Example, Changelog, Installing, Versions, and Scores tabs.
3. Confirm API documentation generated successfully.
4. Open every homepage/repository/issue link.
5. Read the pub points report and fix server-only findings in `0.2.1`.

You cannot replace or delete a published release; corrections require a new
version such as `0.2.1`.

## 7. Transfer to a Verified Publisher

Pub's current first-release flow does not publish a brand-new package directly
to a verified publisher. Publish under the authenticated Google account, then:

1. Open the package page on pub.dev.
2. Open **Admin**.
3. Choose **Transfer to publisher**.
4. Select the verified publisher domain.
5. Confirm the transfer.

Future versions can then be published under that publisher.

## Publishing Updates

For every later release:

1. Increment `version` in `pubspec.yaml`.
2. Add the same version at the top of `CHANGELOG.md`.
3. Update README examples when APIs change.
4. Run the complete preflight and `pana` again.
5. Commit and push the release state.
6. Run `dart pub publish` and inspect the uploaded version.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production iOS releases enforce archive and IPA size budgets', () {
    final workflow = File(
      '../.github/workflows/mobile-release.yml',
    ).readAsStringSync();
    final fastfile = File('fastlane/Fastfile').readAsStringSync();

    expect(workflow, contains('max_app_bytes='));
    expect(workflow, contains('max_archive_bytes='));
    expect(workflow, contains('mediguide-ios-unsigned.zip'));
    expect(fastfile, contains('enforce_artifact_size!'));
    expect(fastfile, contains('MAX_IOS_IPA_BYTES'));
  });

  test('Firebase distribution passes absolute artifact paths to Fastlane', () {
    final fastfile = File('fastlane/Fastfile').readAsStringSync();

    expect(fastfile, contains('binary_path = File.expand_path(binary)'));
    expect(fastfile, contains('android_artifact_path: binary_path.end_with?'));
    expect(fastfile, contains('ipa_path: binary_path.end_with?'));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is ChatiX, `com.forgot.chatix`, on every platform, and the
/// template it was started from is not named anywhere that ships.
///
/// Each check here is a bug that was actually in the tree: a launcher
/// activity left in the template's package (a crash on start, though the APK
/// builds), plists with three values per key from a rename script, test
/// targets signed with the app's own id.
void main() {
  const appId = 'com.forgot.chatix';
  const name = 'ChatiX';

  // A Windows checkout with autocrlf hands these over with CRLF endings.
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('Android', () {
    test('the launcher activity is in the package the manifest names', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('namespace = "$appId"'));
      expect(gradle, contains('applicationId = "$appId"'));

      // ".MainActivity" resolves against the namespace; the class living in
      // any other package is a ClassNotFoundException at launch.
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        contains('android:name=".MainActivity"'),
      );
      final sources = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(sources, [
        'android/app/src/main/kotlin/${appId.replaceAll('.', '/')}/MainActivity.kt',
      ]);
      expect(LineSplitter.split(read(sources.single)).first, 'package $appId');
    });

    test('is labelled $name', () {
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        contains('android:label="@string/app_name"'),
      );
      expect(
        read('android/app/src/main/res/values/strings.xml'),
        contains('<string name="app_name">$name</string>'),
      );
    });
  });

  group('iOS and macOS', () {
    for (final plist in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']) {
      test('$plist gives every key exactly one value', () {
        expect(_keysWithMoreThanOneValue(read(plist)), isEmpty);
      });
    }

    test('iOS shows $name and takes its id from the project', () {
      final values = _topLevelStrings(read('ios/Runner/Info.plist'));
      expect(values['CFBundleDisplayName'], name);
      expect(values['CFBundleName'], name);
      expect(values['CFBundleIdentifier'], r'$(PRODUCT_BUNDLE_IDENTIFIER)');
    });

    test('macOS builds $name.app as $appId', () {
      final config = read('macos/Runner/Configs/AppInfo.xcconfig');
      expect(config, contains('PRODUCT_NAME = $name\n'));
      expect(config, contains('PRODUCT_BUNDLE_IDENTIFIER = $appId\n'));

      final values = _topLevelStrings(read('macos/Runner/Info.plist'));
      expect(values['CFBundleName'], r'$(PRODUCT_NAME)');
      expect(values['CFBundleIdentifier'], r'$(PRODUCT_BUNDLE_IDENTIFIER)');
    });

    for (final project in [
      'ios/Runner.xcodeproj/project.pbxproj',
      'macos/Runner.xcodeproj/project.pbxproj',
    ]) {
      test('$project keeps the test target off the app id', () {
        final ids = RegExp(
          r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
        ).allMatches(read(project)).map((m) => m.group(1)).toSet();
        expect(ids, contains('$appId.RunnerTests'));
        expect(ids.difference({appId, '$appId.RunnerTests'}), isEmpty);
      });
    }
  });

  test('Windows titles the window and the executable $name', () {
    expect(read('windows/runner/main.cpp'), contains('L"$name"'));
    final resources = read('windows/runner/Runner.rc');
    expect(resources, contains('VALUE "ProductName", "$name" "\\0"'));
    expect(resources, contains('VALUE "FileDescription", "$name" "\\0"'));
  });

  test('Linux titles the window $name', () {
    expect(
      read('linux/runner/my_application.cc'),
      contains('gtk_window_set_title(window, "$name");'),
    );
    expect(
      read('linux/CMakeLists.txt'),
      contains('set(APPLICATION_ID "$appId")'),
    );
  });

  test('the web app installs as $name', () {
    final manifest =
        jsonDecode(read('web/manifest.json')) as Map<String, Object?>;
    expect(manifest['name'], name);
    expect(manifest['short_name'], name);
    expect(
      read('web/index.html'),
      contains('<meta name="apple-mobile-web-app-title" content="$name">'),
    );
  });

  test('nothing that ships still names the template', () {
    const forbidden = [
      'flutter_riverpod_clean_architecture',
      'flutterRiverpodCleanArchitecture',
      'Flutter Riverpod Clean Architecture',
      'com.ssoad',
    ];
    const roots = [
      'android/app/src',
      'android/app/build.gradle.kts',
      'ios/Runner',
      'ios/Runner.xcodeproj',
      'macos/Runner',
      'macos/Runner.xcodeproj',
      'windows/runner',
      'windows/CMakeLists.txt',
      'linux/runner',
      'linux/CMakeLists.txt',
      'web',
      'lib',
      '.github/workflows',
      'pubspec.yaml',
    ];
    const text = {
      '.dart',
      '.kt',
      '.java',
      '.kts',
      '.xml',
      '.plist',
      '.pbxproj',
      '.xcscheme',
      '.xcconfig',
      '.storyboard',
      '.cpp',
      '.cc',
      '.h',
      '.rc',
      '.txt',
      '.html',
      '.json',
      '.yml',
      '.yaml',
      '.arb',
      '.swift',
    };

    final hits = <String>[];
    for (final root in roots) {
      final entity = FileSystemEntity.typeSync(root);
      final files = entity == FileSystemEntityType.directory
          ? Directory(root).listSync(recursive: true).whereType<File>()
          : [File(root)];
      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');
        if (!text.any(path.endsWith) || path.contains('/ephemeral/')) continue;
        final content = file.readAsStringSync();
        for (final word in forbidden) {
          if (content.contains(word)) hits.add('$path: $word');
        }
      }
    }
    expect(hits, isEmpty);
  });
}

final _tag = RegExp(
  r'<(/?)(key|string|dict|array|true|false|integer|real|date|data)(\s*/)?>',
);

/// Keys of the root dictionary that are followed by more than one value —
/// what a sed that inserts a line but never deletes one leaves behind. A
/// plist like that is not a plist: Xcode refuses it.
List<String> _keysWithMoreThanOneValue(String plist) {
  final bad = <String>[];
  var depth = 0;
  String? key;
  var values = 0;
  var keyStart = -1;

  for (final m in _tag.allMatches(plist)) {
    final closing = m.group(1) == '/';
    final tag = m.group(2)!;
    final selfClosing = m.group(3) != null || tag == 'true' || tag == 'false';

    if (closing) {
      depth--;
      if (depth == 1 && tag == 'key') {
        key = plist.substring(keyStart, m.start);
        values = 0;
      }
      continue;
    }
    if (depth == 1 && tag == 'key') {
      keyStart = m.end;
    } else if (depth == 1) {
      values++;
      if (values == 2) bad.add(key ?? '?');
    }
    if (!selfClosing) depth++;
  }
  return bad;
}

/// The root dictionary's string values, by key.
Map<String, String> _topLevelStrings(String plist) => {
  for (final m in RegExp(
    r'^\t<key>([^<]+)</key>\s*\n\t<string>([^<]*)</string>',
    multiLine: true,
  ).allMatches(plist.replaceAll('\r\n', '\n')))
    m.group(1)!: m.group(2)!,
};

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Android dependency graph contains no Windows or download implementation',
      () {
    final closure = _collectDartDependencyClosure(
      root: Directory.current,
      startPath: 'lib/main_android.dart',
    );

    expect(
      closure.localPaths.where(_isForbiddenAndroidDependencyPath),
      isEmpty,
    );
    expect(
      closure.externalPackageUris.where(_isForbiddenAndroidPackageUri),
      isEmpty,
    );
  });

  test('shared startup and credential manager have no Windows imports', () {
    final sources = [
      File('lib/bootstrap/app_bootstrap.dart').readAsStringSync(),
      File('lib/services/danmaku/dandanplay_credential_manager.dart')
          .readAsStringSync(),
    ].join('\n');
    expect(sources, isNot(contains('package:window_manager')));
    expect(sources, isNot(contains('package:win32')));
    expect(sources, isNot(contains('windows_danmaku_credential_store')));
  });

  test('bootstrap coordinator has no application composition dependencies', () {
    final source = File('lib/bootstrap/app_bootstrap.dart').readAsStringSync();
    final closure = _collectDartDependencyClosure(
      root: Directory.current,
      startPath: 'lib/bootstrap/app_bootstrap.dart',
    );

    expect(_directCompositionSymbols(source), isEmpty);
    expect(
      closure.localPaths.where(_isForbiddenLocalDependencyPath),
      isEmpty,
    );
    expect(
      closure.externalPackageUris.where(_isForbiddenExternalPackageUri),
      isEmpty,
    );
  });

  test('Android guard blocks download execution but allows shared settings',
      () {
    expect(
      _isForbiddenAndroidDependencyPath(
        'lib/services/download/segment_downloader.dart',
      ),
      isTrue,
    );
    expect(
      _isForbiddenAndroidDependencyPath(
        'lib/services/download/download_settings.dart',
      ),
      isFalse,
    );
  });

  test('relative imports resolve within the Dart package root', () {
    expect(
      _resolveRelativePath(
          'lib/stores/home_store.dart', '../../utils/logger.dart'),
      'lib/utils/logger.dart',
    );
    expect(
      _resolveRelativePath(
        'lib/pages/settings/plugin_detail_page.dart',
        '../../../widgets/vira_state_view.dart',
      ),
      'lib/widgets/vira_state_view.dart',
    );
    expect(
      _resolveRelativePath(
          'tool/nested/script.dart', '../../utils/logger.dart'),
      'utils/logger.dart',
    );
  });

  test('external package guard rejects every forbidden package path', () {
    expect(
      _isForbiddenExternalPackageUri(
        'package:flutter_modular/src/presenter/modular_app.dart',
      ),
      isTrue,
    );
    expect(
      _isForbiddenExternalPackageUri(
          'package:media_kit/src/player/player.dart'),
      isTrue,
    );
    expect(
      _isForbiddenExternalPackageUri('package:flutter/widgets.dart'),
      isFalse,
    );
  });

  test('local dependency guard canonicalizes case and path separators', () {
    for (final forbidden in [
      r'LIB\APP_MODULE.dart',
      'Lib/App_Widget.dart',
      'LIB/Stores/Theme_Store.dart',
      r'lib\PAGES\home_page.dart',
      'LIB/services/PLUGIN/example_plugin.dart',
    ]) {
      expect(
        _isForbiddenLocalDependencyPath(forbidden),
        isTrue,
        reason: forbidden,
      );
    }
    expect(
      _isForbiddenLocalDependencyPath('lib/services/danmaku/service.dart'),
      isFalse,
    );
  });

  test('direct composition guard catches code but ignores text tokens', () {
    final codeSymbols = _directCompositionSymbols('''
void compose() {
  runApp(app);
  ModularApp(module: module, child: child);
  AppModule ();
  AppWidget();
}
''');
    final textSymbols = _directCompositionSymbols(r'''
// runApp(app);
/* ModularApp(module: module, child: child); */
const normal = 'AppModule(';
const raw = r'AppWidget(';
const multiline = """
runApp(
ModularApp(
""";
''');

    expect(
      codeSymbols,
      equals({'runApp(', 'ModularApp(', 'AppModule(', 'AppWidget('}),
    );
    expect(textSymbols, isEmpty);
  });

  test(
      'dependency closure follows indirect barrels without text false positives',
      () {
    final root = Directory.systemTemp.createTempSync('weila-dart-closure-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    _writeFixture(
      root,
      'lib/bootstrap/app_bootstrap.dart',
      "import '../barrel.dart';\n",
    );
    _writeFixture(
      root,
      'lib/barrel.dart',
      """
/*
export 'pages/comment_only.dart';
*/
const misleading = '''
export 'pages/string_only.dart';
''';
export /* 'pages/inline_comment.dart' */ 'app_module.dart';
""",
    );
    _writeFixture(
      root,
      'lib/app_module.dart',
      "import 'package:flutter_modular/flutter_modular.dart';\n",
    );
    _writeFixture(root, 'lib/pages/comment_only.dart', 'const value = 1;\n');
    _writeFixture(root, 'lib/pages/string_only.dart', 'const value = 2;\n');
    _writeFixture(root, 'lib/pages/inline_comment.dart', 'const value = 3;\n');

    final closure = _collectDartDependencyClosure(
      root: root,
      startPath: 'lib/bootstrap/app_bootstrap.dart',
    );

    expect(closure.localPaths, contains('lib/barrel.dart'));
    expect(closure.localPaths, contains('lib/app_module.dart'));
    expect(closure.localPaths, isNot(contains('lib/pages/comment_only.dart')));
    expect(closure.localPaths, isNot(contains('lib/pages/string_only.dart')));
    expect(
        closure.localPaths, isNot(contains('lib/pages/inline_comment.dart')));
    expect(
      closure.externalPackageUris,
      contains('package:flutter_modular/flutter_modular.dart'),
    );
  });

  test('dependency closure follows same-line, conditional and part directives',
      () {
    final root = Directory.systemTemp.createTempSync('weila-dart-closure-');
    addTearDown(() => root.deleteSync(recursive: true));
    _writeFixture(root, 'lib/main_android.dart', '''
import 'package:weila/barrel.dart'; export 'branch.dart';
part 'entry.g.dart';
const part = 'not-an-import.dart';
''');
    _writeFixture(root, 'lib/barrel.dart', '''
export 'safe.dart' if (dart.library.io) 'platform/windows/bridge.dart';
''');
    _writeFixture(root, 'lib/safe.dart', 'const value = 1;');
    _writeFixture(root, 'lib/platform/windows/bridge.dart',
        "import 'package:win32/win32.dart';");
    _writeFixture(root, 'lib/branch.dart',
        "export 'services/download/download_service.dart';");
    _writeFixture(root, 'lib/services/download/download_service.dart',
        "export '../../main_android.dart';");
    _writeFixture(root, 'lib/entry.g.dart', "part of 'main_android.dart';");

    final closure = _collectDartDependencyClosure(
      root: root,
      startPath: 'lib/main_android.dart',
    );
    expect(
        closure.localPaths,
        containsAll([
          'lib/safe.dart',
          'lib/entry.g.dart',
          'lib/branch.dart',
          'lib/platform/windows/bridge.dart',
          'lib/services/download/download_service.dart',
        ]));
    expect(closure.localPaths.where(_isForbiddenAndroidDependencyPath),
        hasLength(2));
    expect(closure.externalPackageUris.where(_isForbiddenAndroidPackageUri),
        contains('package:win32/win32.dart'));
  });

  test('Windows graph retains native implementations and download page', () {
    final closure = _collectDartDependencyClosure(
      root: Directory.current,
      startPath: 'lib/main.dart',
    );
    expect(
        closure.localPaths,
        containsAll([
          'lib/services/download/download_service.dart',
          'lib/pages/download/download_page.dart',
          'lib/services/danmaku/windows_danmaku_credential_store.dart',
        ]));
    expect(
        closure.externalPackageUris,
        containsAll([
          'package:window_manager/window_manager.dart',
          'package:win32/win32.dart',
        ]));
  });

  test('dependency closure rejects missing files', () {
    final root = Directory.systemTemp.createTempSync('weila-dart-closure-');
    addTearDown(() => root.deleteSync(recursive: true));
    _writeFixture(root, 'lib/main.dart', "export 'missing.dart';");
    expect(
      () => _collectDartDependencyClosure(
        root: root,
        startPath: 'lib/main.dart',
      ),
      throwsStateError,
    );
  });

  test('Android capabilities gate routes and settings actions', () {
    final module = File('lib/app_module.dart').readAsStringSync();
    final settings =
        File('lib/pages/settings/settings_page.dart').readAsStringSync();
    expect(module, contains('if (capabilities.pluginEditing)'));
    expect(module, contains('if (capabilities.downloads)'));
    expect(settings, contains('widget.capabilities.pluginEditing'));
    expect(settings, contains('widget.capabilities.downloads'));
    expect(settings, contains('widget.capabilities.secureCredentialStorage'));
  });
}

class _DartDependencyClosure {
  const _DartDependencyClosure({
    required this.localPaths,
    required this.externalPackageUris,
  });

  final Set<String> localPaths;
  final Set<String> externalPackageUris;
}

bool _isForbiddenAndroidDependencyPath(String path) {
  final canonicalPath = _normalizeRelativePath(path).toLowerCase();
  return canonicalPath.startsWith('lib/platform/windows/') ||
      canonicalPath ==
          'lib/services/danmaku/windows_danmaku_credential_store.dart' ||
      canonicalPath == 'lib/services/download/download_service.dart' ||
      canonicalPath == 'lib/services/download/segment_downloader.dart';
}

bool _isForbiddenAndroidPackageUri(String uri) {
  return uri.startsWith('package:window_manager/') ||
      uri.startsWith('package:win32/');
}

bool _isForbiddenExternalPackageUri(String uri) {
  return uri.startsWith('package:flutter_modular/') ||
      uri.startsWith('package:media_kit/');
}

bool _isForbiddenLocalDependencyPath(String path) {
  final canonicalPath = _normalizeRelativePath(path).toLowerCase();
  return const {
        'lib/app_module.dart',
        'lib/app_widget.dart',
        'lib/stores/theme_store.dart',
      }.contains(canonicalPath) ||
      canonicalPath.startsWith('lib/pages/') ||
      canonicalPath.startsWith('lib/services/plugin/');
}

Set<String> _directCompositionSymbols(String source) {
  final code = _maskDartSource(source, maskStrings: true);
  final found = <String>{};
  for (final symbol in const [
    'runApp(',
    'ModularApp(',
    'AppModule(',
    'AppWidget(',
  ]) {
    final name = symbol.substring(0, symbol.length - 1);
    final callPattern = RegExp('\\b${RegExp.escape(name)}\\s*\\(');
    if (callPattern.hasMatch(code)) found.add(symbol);
  }
  return found;
}

_DartDependencyClosure _collectDartDependencyClosure({
  required Directory root,
  required String startPath,
}) {
  final pending = <String>[_normalizeRelativePath(startPath)];
  final visited = <String>{};
  final localPaths = <String>{};
  final externalPackageUris = <String>{};

  while (pending.isNotEmpty) {
    final relativePath = pending.removeLast();
    final visitKey =
        Platform.isWindows ? relativePath.toLowerCase() : relativePath;
    if (!visited.add(visitKey)) continue;

    final file = File('${root.path}/$relativePath');
    if (!file.existsSync()) {
      throw StateError('Local Dart dependency does not exist: $relativePath');
    }
    localPaths.add(relativePath);

    for (final uri in _dartDirectiveUris(file.readAsStringSync())) {
      if (uri.startsWith('package:weila/')) {
        pending.add(
          _normalizeRelativePath(
              'lib/${uri.substring('package:weila/'.length)}'),
        );
      } else if (uri.startsWith('package:')) {
        externalPackageUris.add(uri);
      } else if (!uri.contains(':')) {
        final dependencyPath = _resolveRelativePath(relativePath, uri);
        if (!File('${root.path}/$dependencyPath').existsSync()) {
          throw StateError(
            'Local Dart dependency does not exist: $relativePath -> $uri',
          );
        }
        pending.add(dependencyPath);
      }
    }
  }

  return _DartDependencyClosure(
    localPaths: localPaths,
    externalPackageUris: externalPackageUris,
  );
}

Iterable<String> _dartDirectiveUris(String source) sync* {
  final codeMask = _maskDartSource(source, maskStrings: true);
  final commentMask = _maskDartSource(source, maskStrings: false);
  final directivePattern = RegExp(
    r'(?:^|(?<=;))\s*(?:import|export|part)\b[\s\S]*?;',
  );
  final partOfPattern = RegExp(r'^\s*part\s+of\b');
  final uriPattern = RegExp(
    r'''r?'([^'\r\n]+)'|r?"([^"\r\n]+)"''',
  );

  for (final match in directivePattern.allMatches(codeMask)) {
    final directive = commentMask.substring(match.start, match.end);
    if (partOfPattern.hasMatch(directive)) continue;
    for (final uriMatch in uriPattern.allMatches(directive)) {
      yield uriMatch.group(1) ?? uriMatch.group(2)!;
    }
  }
}

String _maskDartSource(String source, {required bool maskStrings}) {
  final masked = StringBuffer();
  var index = 0;

  void maskCharacter(String character) {
    masked.write(character == '\n' || character == '\r' ? character : ' ');
  }

  void writeStringCharacter(String character) {
    if (maskStrings) {
      maskCharacter(character);
    } else {
      masked.write(character);
    }
  }

  while (index < source.length) {
    if (source.startsWith('//', index)) {
      while (index < source.length && source[index] != '\n') {
        maskCharacter(source[index++]);
      }
      continue;
    }

    if (source.startsWith('/*', index)) {
      var depth = 0;
      while (index < source.length) {
        if (source.startsWith('/*', index)) {
          depth++;
          maskCharacter(source[index++]);
          maskCharacter(source[index++]);
        } else if (source.startsWith('*/', index)) {
          depth--;
          maskCharacter(source[index++]);
          maskCharacter(source[index++]);
          if (depth == 0) break;
        } else {
          maskCharacter(source[index++]);
        }
      }
      continue;
    }

    final character = source[index];
    if (character == "'" || character == '"') {
      final delimiter =
          source.startsWith(character * 3, index) ? character * 3 : character;
      final previousIsRawPrefix = index > 0 &&
          (source[index - 1] == 'r' || source[index - 1] == 'R') &&
          (index == 1 || !_isIdentifierCharacter(source[index - 2]));

      for (var count = 0; count < delimiter.length; count++) {
        writeStringCharacter(source[index++]);
      }
      while (index < source.length) {
        if (source.startsWith(delimiter, index)) {
          for (var count = 0; count < delimiter.length; count++) {
            writeStringCharacter(source[index++]);
          }
          break;
        }
        if (!previousIsRawPrefix && source[index] == '\\') {
          writeStringCharacter(source[index++]);
          if (index < source.length) writeStringCharacter(source[index++]);
          continue;
        }
        writeStringCharacter(source[index++]);
      }
      continue;
    }

    masked.write(character);
    index++;
  }

  return masked.toString();
}

bool _isIdentifierCharacter(String character) {
  return RegExp(r'[A-Za-z0-9_$]').hasMatch(character);
}

String _resolveRelativePath(String fromPath, String uri) {
  if (fromPath.startsWith('lib/')) {
    final packageUri = Uri.parse('package:weila/${fromPath.substring(4)}');
    final resolved = packageUri.resolve(uri);
    return 'lib/${resolved.path.substring('weila/'.length)}';
  }
  final base = fromPath.split('/')..removeLast();
  return _normalizeRelativePath([...base, ...uri.split('/')].join('/'));
}

String _normalizeRelativePath(String path) {
  final normalized = <String>[];
  for (final segment in path.replaceAll('\\', '/').split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (normalized.isEmpty) {
        throw StateError('Local Dart dependency escapes project root: $path');
      }
      normalized.removeLast();
    } else {
      normalized.add(segment);
    }
  }
  return normalized.join('/');
}

void _writeFixture(Directory root, String relativePath, String source) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(source);
}

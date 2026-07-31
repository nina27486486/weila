import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android entry imports no Windows implementation or download service',
      () {
    final source = File('lib/main_android.dart').readAsStringSync();
    for (final forbidden in [
      'package:window_manager',
      'package:win32',
      'windows_danmaku_credential_store',
      'DownloadService',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
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
    final closure = _collectDartDependencyClosure(
      root: Directory.current,
      startPath: 'lib/bootstrap/app_bootstrap.dart',
    );

    expect(closure.localPaths, isNot(contains('lib/app_module.dart')));
    expect(closure.localPaths, isNot(contains('lib/app_widget.dart')));
    expect(closure.localPaths, isNot(contains('lib/stores/theme_store.dart')));
    expect(
      closure.localPaths.where((path) => path.startsWith('lib/pages/')),
      isEmpty,
    );
    expect(
      closure.localPaths
          .where((path) => path.startsWith('lib/services/plugin/')),
      isEmpty,
    );
    expect(
      closure.externalPackageUris,
      isNot(contains('package:flutter_modular/flutter_modular.dart')),
    );
    expect(
      closure.externalPackageUris,
      isNot(contains('package:media_kit/media_kit.dart')),
    );
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
        pending.add(_resolveRelativePath(relativePath, uri));
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
    r'^[ \t]*(?:import|export|part)\b[\s\S]*?;',
    multiLine: true,
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

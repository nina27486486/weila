import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

import '../../models/playback/playback_source.dart';

typedef YinhuaHtmlLoader = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
);

/// Resolves Yinhua's current website playback chain without embedding a web
/// player: episode page token -> mcue parser page -> final HLS manifest.
class YinhuaPlaybackResolver {
  const YinhuaPlaybackResolver({required YinhuaHtmlLoader loadHtml})
      : _loadHtml = loadHtml;

  final YinhuaHtmlLoader _loadHtml;

  Future<PlaybackEpisode> resolveEpisode({
    required Uri baseUrl,
    required String cmsId,
    required PlaybackEpisode episode,
  }) async {
    final sources = await Future.wait(
      episode.sources.map((source) async {
        try {
          return await resolveSource(
            baseUrl: baseUrl,
            cmsId: cmsId,
            source: source,
          );
        } catch (_) {
          return source;
        }
      }),
    );
    return PlaybackEpisode(
      name: episode.name,
      index: episode.index,
      sources: sources,
    );
  }

  Future<PlaybackSource> resolveSource({
    required Uri baseUrl,
    required String cmsId,
    required PlaybackSource source,
  }) async {
    if (source.variants.isEmpty) {
      throw const FormatException('Yinhua source has no playback variant');
    }
    final route = _oneBasedSuffix(source.id) + 1;
    final episode = _oneBasedSuffix(source.variants.first.id);
    final playbackPage = baseUrl.resolve('/p/$cmsId-$route-$episode.html');
    final pageHtml = await _loadHtml(playbackPage, source.headers);
    final token = _extractPlayerToken(pageHtml);

    final parserPage = Uri.https(
      'player.mcue.cc',
      '/yinhua/',
      <String, String>{'url': token},
    );
    final parserHeaders = Map<String, String>.from(source.headers)
      ..['Referer'] = playbackPage.toString();
    final parserHtml = await _loadHtml(parserPage, parserHeaders);
    final manifestUrl = _decryptManifestUrl(parserHtml);

    final mediaHeaders = Map<String, String>.from(source.headers)
      ..remove('Referer')
      ..remove('referer')
      ..remove('Origin')
      ..remove('origin');
    final original = source.variants.first;
    return PlaybackSource(
      id: source.id,
      label: source.label,
      kind: source.kind,
      headers: mediaHeaders,
      variants: [
        PlaybackVariant(
          id: original.id,
          label: original.label,
          url: manifestUrl,
          kind: PlaybackVariantKind.hls,
        ),
      ],
    );
  }

  static int _oneBasedSuffix(String value) {
    final match = RegExp(r'-(\d+)$').firstMatch(value);
    final parsed = match == null ? null : int.tryParse(match.group(1)!);
    if (parsed == null || parsed < 0) {
      throw FormatException('Invalid Yinhua playback identifier: $value');
    }
    return parsed;
  }

  static String _extractPlayerToken(String html) {
    final match = RegExp(
      r'var\s+player_aaaa\s*=\s*(\{.*?\})\s*</script>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      throw const FormatException('Yinhua playback token was not found');
    }
    final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final token = data['url']?.toString().trim() ?? '';
    if (!token.startsWith('MCZY-')) {
      throw const FormatException('Yinhua playback token is invalid');
    }
    return token;
  }

  static String _decryptManifestUrl(String html) {
    final document = html_parser.parse(html);
    final viewportId = document.querySelector('meta[name="viewport"]')?.id ?? '';
    final charsetId = document.querySelector('meta[charset]')?.id ?? '';
    final viewportKey = _stripDynamicPrefix(viewportId);
    final charsetKey = _stripDynamicPrefix(charsetId);
    if (viewportKey.isEmpty || viewportKey.length != charsetKey.length) {
      throw const FormatException('Yinhua parser key metadata is invalid');
    }

    final configStart = html.indexOf(RegExp(r'var\s+config\s*=', caseSensitive: false));
    if (configStart < 0) {
      throw const FormatException('Yinhua parser config was not found');
    }
    final configWindow = html.substring(
      configStart,
      (configStart + 5000).clamp(0, html.length),
    );
    final encryptedMatch = RegExp(
      r'["\x27]url["\x27]\s*:\s*["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(configWindow);
    if (encryptedMatch == null) {
      throw const FormatException('Yinhua encrypted manifest was not found');
    }

    final pairs = <_KeyCharacter>[];
    for (var index = 0; index < charsetKey.length; index++) {
      final order = int.tryParse(charsetKey[index]);
      if (order == null) {
        throw const FormatException('Yinhua parser key order is invalid');
      }
      pairs.add(_KeyCharacter(order, viewportKey[index]));
    }
    pairs.sort((left, right) => left.order.compareTo(right.order));
    final seed = pairs.map((pair) => pair.character).join();
    final digest = md5.convert(utf8.encode('${seed}lemon')).toString();
    final iv = Uint8List.fromList(utf8.encode(digest.substring(0, 16)));
    final key = Uint8List.fromList(utf8.encode(digest.substring(16)));

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        false,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    final decrypted = utf8.decode(
      cipher.process(
        Uint8List.fromList(base64Decode(encryptedMatch.group(1)!)),
      ),
    );
    final uri = Uri.tryParse(decrypted.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Yinhua decrypted manifest URL is invalid');
    }
    return uri.toString();
  }

  static String _stripDynamicPrefix(String value) {
    return value.startsWith('now_') ? value.substring(4) : '';
  }
}

class _KeyCharacter {
  const _KeyCharacter(this.order, this.character);

  final int order;
  final String character;
}

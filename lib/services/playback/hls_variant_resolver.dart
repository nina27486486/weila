import '../../models/playback/playback_source.dart';
import 'hls_master_playlist_parser.dart';

typedef HlsManifestLoader = Future<String> Function(
  Uri manifestUri,
  Map<String, String> headers,
);

class HlsVariantResolver {
  HlsVariantResolver({
    required HlsManifestLoader loadManifest,
    HlsMasterPlaylistParser parser = const HlsMasterPlaylistParser(),
  })  : _loadManifest = loadManifest,
        _parser = parser;

  final HlsManifestLoader _loadManifest;
  final HlsMasterPlaylistParser _parser;

  Future<PlaybackSource> resolve(PlaybackSource source) async {
    PlaybackVariant? original;
    for (final variant in source.variants) {
      if (variant.kind == PlaybackVariantKind.original) {
        original = variant;
        break;
      }
    }
    if (original == null) return source;

    final uri = Uri.tryParse(original.url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return source;
    }
    final normalizedUrl = original.url.toLowerCase();
    if (!normalizedUrl.contains('.m3u8') &&
        !normalizedUrl.contains('/hls/') &&
        !normalizedUrl.contains('type=hls')) {
      return source;
    }

    try {
      final body = await _loadManifest(uri, source.headers);
      final variants = _parser.parse(manifestUri: uri, body: body);
      if (variants.isEmpty) return source;
      return PlaybackSource(
        id: source.id,
        label: source.label,
        kind: source.kind,
        variants: variants,
        headers: source.headers,
      );
    } catch (_) {
      return source;
    }
  }
}

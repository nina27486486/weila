import '../../models/playback/playback_source.dart';

class HlsMasterPlaylistParser {
  const HlsMasterPlaylistParser();

  List<PlaybackVariant> parse({
    required Uri manifestUri,
    required String body,
  }) {
    final lines = body.split(RegExp(r'\r?\n'));
    final variants = <PlaybackVariant>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;

      final attributes = _parseAttributes(
        line.substring('#EXT-X-STREAM-INF:'.length),
      );
      String? uriText;
      for (var next = index + 1; next < lines.length; next++) {
        final candidate = lines[next].trim();
        if (candidate.isEmpty || candidate.startsWith('#')) continue;
        uriText = candidate;
        index = next;
        break;
      }
      if (uriText == null) continue;

      final resolution = _parseResolution(attributes['RESOLUTION']);
      final bitrate = int.tryParse(
        attributes['AVERAGE-BANDWIDTH'] ?? attributes['BANDWIDTH'] ?? '',
      );
      final height = resolution?.$2;
      final label = height != null
          ? '${height}P'
          : bitrate != null
              ? '码率 ${(bitrate / 1000).round()} kbps'
              : '原始';

      variants.add(
        PlaybackVariant(
          id: 'hls-${variants.length}',
          label: label,
          url: manifestUri.resolve(uriText).toString(),
          kind: PlaybackVariantKind.hls,
          width: resolution?.$1,
          height: height,
          bitrate: bitrate,
        ),
      );
    }

    return List<PlaybackVariant>.unmodifiable(variants);
  }

  Map<String, String> _parseAttributes(String value) {
    final attributes = <String, String>{};
    final pattern = RegExp(r'(?:^|,)([A-Z0-9-]+)=("[^"]*"|[^,]*)');
    for (final match in pattern.allMatches(value)) {
      final key = match.group(1);
      var attributeValue = match.group(2);
      if (key == null || attributeValue == null) continue;
      if (attributeValue.length >= 2 &&
          attributeValue.startsWith('"') &&
          attributeValue.endsWith('"')) {
        attributeValue = attributeValue.substring(1, attributeValue.length - 1);
      }
      attributes[key] = attributeValue;
    }
    return attributes;
  }

  (int, int)? _parseResolution(String? value) {
    if (value == null) return null;
    final match =
        RegExp(r'^(\d+)x(\d+)$', caseSensitive: false).firstMatch(value);
    if (match == null) return null;
    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    if (width == null || height == null) return null;
    return (width, height);
  }
}

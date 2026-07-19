import 'dart:collection';

enum PlaybackSourceKind { direct, cms, html }

enum PlaybackVariantKind { original, hls }

class PlaybackVariant {
  const PlaybackVariant({
    required this.id,
    required this.label,
    required this.url,
    required this.kind,
    this.width,
    this.height,
    this.bitrate,
  });

  final String id;
  final String label;
  final String url;
  final PlaybackVariantKind kind;
  final int? width;
  final int? height;
  final int? bitrate;
}

class PlaybackSource {
  PlaybackSource({
    required this.id,
    required this.label,
    required this.kind,
    required Iterable<PlaybackVariant> variants,
    Map<String, String> headers = const {},
  })  : variants = List<PlaybackVariant>.unmodifiable(variants),
        headers = UnmodifiableMapView<String, String>(
          Map<String, String>.from(headers),
        );

  final String id;
  final String label;
  final PlaybackSourceKind kind;
  final List<PlaybackVariant> variants;
  final Map<String, String> headers;
}

class PlaybackEpisode {
  PlaybackEpisode({
    required this.name,
    required this.index,
    required Iterable<PlaybackSource> sources,
  }) : sources = List<PlaybackSource>.unmodifiable(sources);

  final String name;
  final int index;
  final List<PlaybackSource> sources;
}

class PlaybackSelection {
  const PlaybackSelection.auto()
      : sourceId = null,
        variantId = null;

  const PlaybackSelection.source(this.sourceId) : variantId = null;

  const PlaybackSelection.variant(this.sourceId, this.variantId);

  final String? sourceId;
  final String? variantId;

  ResolvedPlayback? resolve(List<PlaybackSource> sources) {
    PlaybackSource? source;
    if (sourceId == null) {
      if (sources.isEmpty) return null;
      source = sources.first;
    } else {
      for (final candidate in sources) {
        if (candidate.id == sourceId) {
          source = candidate;
          break;
        }
      }
      if (source == null) return null;
    }

    PlaybackVariant? variant;
    if (variantId == null) {
      if (source.variants.isEmpty) return null;
      variant = source.variants.first;
    } else {
      for (final candidate in source.variants) {
        if (candidate.id == variantId) {
          variant = candidate;
          break;
        }
      }
      if (variant == null) return null;
    }

    return ResolvedPlayback(source: source, variant: variant);
  }
}

class ResolvedPlayback {
  const ResolvedPlayback({
    required this.source,
    required this.variant,
  });

  final PlaybackSource source;
  final PlaybackVariant variant;
}

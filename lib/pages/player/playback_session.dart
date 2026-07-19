import '../../models/playback/playback_source.dart';

class PlaybackOpenRequest {
  const PlaybackOpenRequest({
    required this.source,
    required this.variant,
    required this.resumePosition,
  });

  final PlaybackSource source;
  final PlaybackVariant variant;
  final Duration resumePosition;

  String get url => variant.url;
  Map<String, String> get headers => source.headers;
}

class PlaybackSession {
  PlaybackSession(List<PlaybackSource> sources)
      : _sources = List<PlaybackSource>.unmodifiable(sources);

  List<PlaybackSource> _sources;
  PlaybackSelection _selection = const PlaybackSelection.auto();

  PlaybackSelection get selection => _selection;
  List<PlaybackSource> get sources => _sources;

  PlaybackOpenRequest? openAt(Duration position) {
    return _requestFor(_selection, position);
  }

  PlaybackOpenRequest? selectSource(String sourceId, Duration position) {
    final next = PlaybackSelection.source(sourceId);
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  PlaybackOpenRequest? selectAuto(Duration position) {
    const next = PlaybackSelection.auto();
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  PlaybackOpenRequest? selectVariant(String variantId, Duration position) {
    final current = _selection.resolve(_sources);
    if (current == null) return null;
    final next = PlaybackSelection.variant(current.source.id, variantId);
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  PlaybackOpenRequest? selectAutoVariant(Duration position) {
    final current = _selection.resolve(_sources);
    if (current == null) return null;
    final next = _selection.sourceId == null
        ? const PlaybackSelection.auto()
        : PlaybackSelection.source(current.source.id);
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  PlaybackOpenRequest? selectNextVariant(Duration position) {
    final current = _selection.resolve(_sources);
    if (current == null) return null;
    final variants = current.source.variants;
    final currentIndex = variants.indexWhere(
      (variant) => variant.id == current.variant.id,
    );
    if (currentIndex < 0 || currentIndex + 1 >= variants.length) return null;
    final next = PlaybackSelection.variant(
      current.source.id,
      variants[currentIndex + 1].id,
    );
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  PlaybackOpenRequest? selectNextSource(Duration position) {
    final current = _selection.resolve(_sources);
    if (current == null) return null;
    return selectNextSourceAfter(current.source.id, position);
  }

  PlaybackOpenRequest? selectNextSourceAfter(
    String activeSourceId,
    Duration position,
  ) {
    final activeIndex = _sources.indexWhere(
      (source) => source.id == activeSourceId,
    );
    final nextIndex = activeIndex < 0 ? 0 : activeIndex + 1;
    if (nextIndex >= _sources.length) return null;
    final next = PlaybackSelection.source(_sources[nextIndex].id);
    final request = _requestFor(next, position);
    if (request == null) return null;
    _selection = next;
    return request;
  }

  void replaceSource(PlaybackSource resolvedSource) {
    final sourceIndex = _sources.indexWhere(
      (source) => source.id == resolvedSource.id,
    );
    if (sourceIndex < 0) return;
    final updated = List<PlaybackSource>.from(_sources);
    updated[sourceIndex] = resolvedSource;
    _sources = List<PlaybackSource>.unmodifiable(updated);

    if (_selection.sourceId != resolvedSource.id ||
        _selection.variantId == null) {
      return;
    }
    final selectedVariantStillExists = resolvedSource.variants.any(
      (variant) => variant.id == _selection.variantId,
    );
    if (!selectedVariantStillExists) {
      _selection = PlaybackSelection.source(resolvedSource.id);
    }
  }

  void replaceSources(List<PlaybackSource> sources) {
    _sources = List<PlaybackSource>.unmodifiable(sources);
    if (_selection.resolve(_sources) != null) return;
    final selectedSourceId = _selection.sourceId;
    final selectedSource = selectedSourceId == null
        ? null
        : _sources.where((source) => source.id == selectedSourceId).firstOrNull;
    _selection = selectedSource == null
        ? const PlaybackSelection.auto()
        : PlaybackSelection.source(selectedSource.id);
  }

  PlaybackOpenRequest? _requestFor(
    PlaybackSelection selection,
    Duration position,
  ) {
    final resolved = selection.resolve(_sources);
    if (resolved == null) return null;
    return PlaybackOpenRequest(
      source: resolved.source,
      variant: resolved.variant,
      resumePosition:
          position > const Duration(seconds: 1) ? position : Duration.zero,
    );
  }
}

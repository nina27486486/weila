import '../../models/playback/playback_source.dart';
import 'playback_probe_service.dart';
import 'playback_route_health.dart';

class PlaybackAutoCandidate {
  const PlaybackAutoCandidate({
    required this.source,
    required this.originalIndex,
    required this.key,
    this.health,
    this.probe,
  });

  final PlaybackSource source;
  final int originalIndex;
  final PlaybackRouteKey key;
  final PlaybackRouteHealth? health;
  final PlaybackProbeResult? probe;
}

class PlaybackAutoSelector {
  const PlaybackAutoSelector();

  List<PlaybackSource> order(
    List<PlaybackAutoCandidate> candidates, {
    required DateTime now,
  }) {
    final playable = candidates
        .where((candidate) => candidate.source.variants.isNotEmpty)
        .toList();
    final currentlyFailed = playable
        .where((candidate) => candidate.probe?.success == false)
        .toSet();
    final available = playable
        .where((candidate) => !currentlyFailed.contains(candidate))
        .toList();
    final known = available
        .where((candidate) => candidate.health?.hasEnoughSamples == true)
        .toList()
      ..sort((a, b) {
        final scoreOrder = b.health!.score(now).compareTo(a.health!.score(now));
        if (scoreOrder != 0) return scoreOrder;
        return a.originalIndex.compareTo(b.originalIndex);
      });
    final unknown = available
        .where((candidate) => candidate.health?.hasEnoughSamples != true)
        .toList()
      ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
    final failed = currentlyFailed.toList()
      ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
    return List<PlaybackSource>.unmodifiable([
      ...known.map((candidate) => candidate.source),
      ...unknown.map((candidate) => candidate.source),
      ...failed.map((candidate) => candidate.source),
    ]);
  }
}

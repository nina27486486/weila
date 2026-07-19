import '../../models/anime.dart';
import '../../models/playback/playback_source.dart';
import '../../models/plugin.dart';

class PluginPlaybackEpisodeAdapter {
  const PluginPlaybackEpisodeAdapter();

  PlaybackEpisode fromHtml({
    required Episode episode,
    required Plugin plugin,
    required List<String> urls,
  }) {
    final candidates = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (candidates.isEmpty) {
      return PlaybackEpisode(
        name: episode.name,
        index: episode.index,
        sources: const [],
      );
    }

    final multiple = candidates.length > 1;
    final variants = <PlaybackVariant>[
      for (var index = 0; index < candidates.length; index++)
        PlaybackVariant(
          id: 'html-$index',
          label: multiple ? '原始 ${index + 1}' : '原始',
          url: candidates[index],
          kind: PlaybackVariantKind.original,
        ),
    ];
    final headers = <String, String>{
      if (plugin.userAgent.trim().isNotEmpty)
        'User-Agent': plugin.userAgent.trim(),
      if (plugin.referer?.trim().isNotEmpty == true)
        'Referer': plugin.referer!.trim(),
    };

    return PlaybackEpisode(
      name: episode.name,
      index: episode.index,
      sources: [
        PlaybackSource(
          id: 'html-default',
          label: '默认线路',
          kind: PlaybackSourceKind.html,
          variants: variants,
          headers: headers,
        ),
      ],
    );
  }
}

class DanmakuMatchCandidate {
  const DanmakuMatchCandidate({
    required this.animeId,
    required this.animeTitle,
    required this.typeDescription,
    required this.episodeId,
    required this.episodeTitle,
    required this.score,
  });

  final int animeId;
  final String animeTitle;
  final String typeDescription;
  final int episodeId;
  final String episodeTitle;
  final int score;
}

class DanmakuMatchDecision {
  DanmakuMatchDecision({
    required Iterable<DanmakuMatchCandidate> candidates,
    this.selected,
  }) : candidates = List<DanmakuMatchCandidate>.unmodifiable(candidates);

  final List<DanmakuMatchCandidate> candidates;
  final DanmakuMatchCandidate? selected;

  bool get ambiguous => selected == null && candidates.isNotEmpty;
}

class DanmakuMatcher {
  const DanmakuMatcher();

  DanmakuMatchDecision match({
    required String requestedAnime,
    required int requestedEpisode,
    required Map<String, dynamic> response,
  }) {
    final requestedTitle = _normalize(requestedAnime);
    final scored = <_IndexedCandidate>[];
    var responseIndex = 0;
    final animes = response['animes'];
    if (animes is! List) {
      return DanmakuMatchDecision(candidates: const []);
    }
    for (final animeValue in animes) {
      if (animeValue is! Map) continue;
      final animeId = animeValue['animeId'];
      final animeTitle = animeValue['animeTitle']?.toString().trim() ?? '';
      final episodes = animeValue['episodes'];
      if (animeId is! int || animeTitle.isEmpty || episodes is! List) continue;
      final candidateTitle = _normalize(animeTitle);
      final titleScore = _titleScore(
        requestedTitle,
        candidateTitle,
      );
      for (final episodeValue in episodes) {
        if (episodeValue is! Map) continue;
        final episodeId = episodeValue['episodeId'];
        final episodeTitle =
            episodeValue['episodeTitle']?.toString().trim() ?? '';
        if (episodeId is! int ||
            episodeTitle.isEmpty ||
            _episodeNumber(episodeTitle) != requestedEpisode) {
          continue;
        }
        scored.add(
          _IndexedCandidate(
            index: responseIndex++,
            candidate: DanmakuMatchCandidate(
              animeId: animeId,
              animeTitle: animeTitle,
              typeDescription:
                  animeValue['typeDescription']?.toString().trim() ?? '',
              episodeId: episodeId,
              episodeTitle: episodeTitle,
              score: titleScore,
            ),
          ),
        );
      }
    }
    scored.sort((a, b) {
      final scoreOrder = b.candidate.score.compareTo(a.candidate.score);
      return scoreOrder == 0 ? a.index.compareTo(b.index) : scoreOrder;
    });
    final candidates = scored.map((item) => item.candidate).toList();
    DanmakuMatchCandidate? selected;
    if (candidates.isNotEmpty && candidates.first.score >= 80) {
      final lead = candidates.length == 1
          ? 1000
          : candidates.first.score - candidates[1].score;
      if (lead >= 10) selected = candidates.first;
    }
    return DanmakuMatchDecision(
      candidates: candidates,
      selected: selected,
    );
  }

  int _titleScore(String requested, String candidate) {
    if (requested.isEmpty || candidate.isEmpty) return 0;
    var score = requested == candidate
        ? 100
        : requested.contains(candidate) || candidate.contains(requested)
            ? 80
            : 0;
    if (_hasConflictingEdition(requested, candidate)) score -= 30;
    return score.clamp(0, 100);
  }

  bool _hasConflictingEdition(String requested, String candidate) {
    const markers = <String>[
      '第二季',
      '第三季',
      '第四季',
      'season2',
      'season3',
      'season4',
      'part2',
      'part3',
      '剧场版',
      'movie',
    ];
    for (final marker in markers) {
      if (requested.contains(marker) != candidate.contains(marker)) return true;
    }
    return false;
  }

  int? _episodeNumber(String title) {
    final match = RegExp(r'\d+').firstMatch(_toHalfWidth(title));
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  String _normalize(String value) {
    final halfWidth = _toHalfWidth(value).toLowerCase();
    var normalized = halfWidth.replaceAll(
      RegExp(r'[\s·・:：,，.。!！?？\-—_()（）\[\]【】《》<>×∞]'),
      '',
    );
    const seasonAliases = <String, String>{
      '第二季': 'season2',
      '第2季': 'season2',
      '2ndseason': 'season2',
      '第三季': 'season3',
      '第3季': 'season3',
      '3rdseason': 'season3',
      '第四季': 'season4',
      '第4季': 'season4',
      '4thseason': 'season4',
    };
    for (final alias in seasonAliases.entries) {
      normalized = normalized.replaceAll(alias.key, alias.value);
    }
    for (var season = 2; season <= 4; season++) {
      final suffix = '$season';
      if (normalized.endsWith(suffix) &&
          !normalized.endsWith('season$suffix') &&
          !normalized.endsWith('part$suffix')) {
        normalized =
            '${normalized.substring(0, normalized.length - 1)}season$suffix';
      }
    }
    return normalized;
  }

  String _toHalfWidth(String value) {
    final result = StringBuffer();
    for (final rune in value.runes) {
      if (rune == 0x3000) {
        result.write(' ');
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        result.writeCharCode(rune - 0xFEE0);
      } else {
        result.writeCharCode(rune);
      }
    }
    return result.toString();
  }
}

class _IndexedCandidate {
  const _IndexedCandidate({required this.index, required this.candidate});

  final int index;
  final DanmakuMatchCandidate candidate;
}

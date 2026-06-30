import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import 'editorial_ranking_view.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final _pluginService = PluginService();

  List<Map<String, dynamic>> _rankingList = [];
  Map<String, int> _previousRanks = {};
  bool _loading = true;
  bool _hasComparison = false;
  String? _error;
  String _source = 'jikan';
  String _scoreFilter = 'all';
  String _statusFilter = 'all';
  String? _genreFilter;

  @override
  void initState() {
    super.initState();
    _loadRanking(compareWithCurrent: false);
  }

  Future<void> _loadRanking({bool compareWithCurrent = true}) async {
    final requestedSource = _source;
    final oldRanks = <String, int>{
      for (var index = 0; index < _rankingList.length; index++)
        _itemKey(_rankingList[index]): index + 1,
    };

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = requestedSource == 'jikan'
          ? await _pluginService.getJikanTopAnime()
          : await _pluginService.getCmsRanking(
              pluginApi: 'cms_yinhua',
              pages: 3,
            );
      if (!mounted || requestedSource != _source) return;
      setState(() {
        _rankingList = list;
        _previousRanks = compareWithCurrent ? oldRanks : {};
        _hasComparison = compareWithCurrent && oldRanks.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (requestedSource == 'jikan') {
        final recovered = await _fallbackToCms();
        if (recovered) return;
      }
      if (!mounted || requestedSource != _source) return;
      setState(() {
        _error = '排行榜暂时走神了，请稍后再试。';
        _loading = false;
      });
    }
  }

  Future<bool> _fallbackToCms() async {
    try {
      final list = await _pluginService.getCmsRanking(
        pluginApi: 'cms_yinhua',
        pages: 3,
      );
      if (!mounted || _source != 'jikan') return false;
      setState(() {
        _rankingList = list;
        _previousRanks = {};
        _hasComparison = false;
        _loading = false;
        _source = 'cms';
        _genreFilter = null;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  void _changeSource(String value) {
    if (_source == value) return;
    setState(() {
      _source = value;
      _genreFilter = null;
      _previousRanks = {};
      _hasComparison = false;
    });
    _loadRanking(compareWithCurrent: false);
  }

  void _resetFilters() {
    setState(() {
      _scoreFilter = 'all';
      _statusFilter = 'all';
      _genreFilter = null;
    });
  }

  String _itemKey(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    return url.isNotEmpty ? url : item['name']?.toString() ?? '';
  }

  double? _scoreOf(Map<String, dynamic> item) {
    final value = item['score'];
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
  }

  List<String> _genresOf(Map<String, dynamic> item) {
    final value = item['genres'];
    if (value is! List) return const [];
    return value
        .map((genre) => genre.toString())
        .where((genre) => genre.isNotEmpty)
        .toList(growable: false);
  }

  bool _matchesStatus(Map<String, dynamic> item) {
    if (_statusFilter == 'all') return true;
    final status = item['status']?.toString().toLowerCase() ?? '';
    if (_statusFilter == 'airing') {
      return status.contains('air') ||
          status.contains('连载') ||
          status.contains('放送') ||
          status.contains('更新');
    }
    return status.contains('finish') ||
        status.contains('完结') ||
        status.contains('完毕');
  }

  List<Map<String, dynamic>> get _filteredList {
    return _rankingList.where((item) {
      final score = _scoreOf(item) ?? 0;
      final matchesScore = switch (_scoreFilter) {
        '8.0' => score >= 8,
        '8.5' => score >= 8.5,
        _ => true,
      };
      final matchesGenre =
          _genreFilter == null || _genresOf(item).contains(_genreFilter);
      return matchesScore && matchesGenre && _matchesStatus(item);
    }).toList(growable: false);
  }

  List<String> get _availableGenres {
    final counts = <String, int>{};
    for (final item in _rankingList) {
      for (final genre in _genresOf(item)) {
        counts.update(genre, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final genres = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return genres.take(10).toList(growable: false);
  }

  bool get _hasActiveFilters =>
      _scoreFilter != 'all' || _statusFilter != 'all' || _genreFilter != null;

  int _absoluteRank(Map<String, dynamic> item) {
    final key = _itemKey(item);
    final index = _rankingList.indexWhere((entry) => _itemKey(entry) == key);
    return index < 0 ? 0 : index + 1;
  }

  int? _rankDelta(Map<String, dynamic> item) {
    if (!_hasComparison) return null;
    final oldRank = _previousRanks[_itemKey(item)];
    return oldRank == null ? null : oldRank - _absoluteRank(item);
  }

  @override
  Widget build(BuildContext context) {
    final stories = _filteredList
        .map(
          (item) => RankingStory(
            item: item,
            rank: _absoluteRank(item),
            score: _scoreOf(item),
            genres: _genresOf(item),
            delta: _rankDelta(item),
          ),
        )
        .toList(growable: false);

    return ViraPageScaffold(
      activeDestination: ViraDestination.discover,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: EditorialRankingView(
        stories: stories,
        source: _source,
        scoreFilter: _scoreFilter,
        statusFilter: _statusFilter,
        genreFilter: _genreFilter,
        availableGenres: _availableGenres,
        hasActiveFilters: _hasActiveFilters,
        hasComparison: _hasComparison,
        isLoading: _loading,
        errorMessage: _error,
        onSourceChanged: _changeSource,
        onScoreChanged: (value) => setState(() => _scoreFilter = value),
        onStatusChanged: (value) => setState(() => _statusFilter = value),
        onGenreChanged: (value) => setState(() => _genreFilter = value),
        onResetFilters: _resetFilters,
        onOpenAnime: _openDetail,
        onRefresh: _loadRanking,
      ),
    );
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    if (destination != ViraDestination.discover) {
      Modular.to.navigate(route);
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (url.isEmpty) return;
    Modular.to.pushNamed(
      '/detail?url=${Uri.encodeComponent(url)}'
      '&name=${Uri.encodeComponent(name)}',
    );
  }
}

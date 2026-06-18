// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AnimeStore on _AnimeStore, Store {
  // No computed properties

  late final _$searchResultsAtom =
      Atom(name: '_AnimeStore.searchResults', context: context);

  @override
  ObservableList<Anime> get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<Anime> value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
    });
  }

  late final _$popularListAtom =
      Atom(name: '_AnimeStore.popularList', context: context);

  @override
  ObservableList<Anime> get popularList {
    _$popularListAtom.reportRead();
    return super.popularList;
  }

  @override
  set popularList(ObservableList<Anime> value) {
    _$popularListAtom.reportWrite(value, super.popularList, () {
      super.popularList = value;
    });
  }

  late final _$currentEpisodesAtom =
      Atom(name: '_AnimeStore.currentEpisodes', context: context);

  @override
  ObservableList<Episode> get currentEpisodes {
    _$currentEpisodesAtom.reportRead();
    return super.currentEpisodes;
  }

  @override
  set currentEpisodes(ObservableList<Episode> value) {
    _$currentEpisodesAtom.reportWrite(value, super.currentEpisodes, () {
      super.currentEpisodes = value;
    });
  }

  late final _$currentDetailAtom =
      Atom(name: '_AnimeStore.currentDetail', context: context);

  @override
  Map<String, dynamic>? get currentDetail {
    _$currentDetailAtom.reportRead();
    return super.currentDetail;
  }

  @override
  set currentDetail(Map<String, dynamic>? value) {
    _$currentDetailAtom.reportWrite(value, super.currentDetail, () {
      super.currentDetail = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_AnimeStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isLoadingEpisodesAtom =
      Atom(name: '_AnimeStore.isLoadingEpisodes', context: context);

  @override
  bool get isLoadingEpisodes {
    _$isLoadingEpisodesAtom.reportRead();
    return super.isLoadingEpisodes;
  }

  @override
  set isLoadingEpisodes(bool value) {
    _$isLoadingEpisodesAtom.reportWrite(value, super.isLoadingEpisodes, () {
      super.isLoadingEpisodes = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_AnimeStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$lastKeywordAtom =
      Atom(name: '_AnimeStore.lastKeyword', context: context);

  @override
  String get lastKeyword {
    _$lastKeywordAtom.reportRead();
    return super.lastKeyword;
  }

  @override
  set lastKeyword(String value) {
    _$lastKeywordAtom.reportWrite(value, super.lastKeyword, () {
      super.lastKeyword = value;
    });
  }

  late final _$searchAsyncAction =
      AsyncAction('_AnimeStore.search', context: context);

  @override
  Future<void> search(String keyword) {
    return _$searchAsyncAction.run(() => super.search(keyword));
  }

  late final _$loadEpisodesAsyncAction =
      AsyncAction('_AnimeStore.loadEpisodes', context: context);

  @override
  Future<void> loadEpisodes(Anime anime) {
    return _$loadEpisodesAsyncAction.run(() => super.loadEpisodes(anime));
  }

  late final _$getVideoUrlsAsyncAction =
      AsyncAction('_AnimeStore.getVideoUrls', context: context);

  @override
  Future<List<String>> getVideoUrls(Anime anime, Episode episode) {
    return _$getVideoUrlsAsyncAction
        .run(() => super.getVideoUrls(anime, episode));
  }

  late final _$_AnimeStoreActionController =
      ActionController(name: '_AnimeStore', context: context);

  @override
  void clearSearch() {
    final _$actionInfo = _$_AnimeStoreActionController.startAction(
        name: '_AnimeStore.clearSearch');
    try {
      return super.clearSearch();
    } finally {
      _$_AnimeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearEpisodes() {
    final _$actionInfo = _$_AnimeStoreActionController.startAction(
        name: '_AnimeStore.clearEpisodes');
    try {
      return super.clearEpisodes();
    } finally {
      _$_AnimeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
searchResults: ${searchResults},
popularList: ${popularList},
currentEpisodes: ${currentEpisodes},
isLoading: ${isLoading},
isLoadingEpisodes: ${isLoadingEpisodes},
errorMessage: ${errorMessage},
lastKeyword: ${lastKeyword},
hasResults: N/A
    ''';
  }
}

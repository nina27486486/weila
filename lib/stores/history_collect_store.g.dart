// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_collect_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HistoryCollectStore on _HistoryCollectStore, Store {
  late final _$_mutationCounterAtom =
      Atom(name: '_HistoryCollectStore._mutationCounter', context: context);

  @override
  int get _mutationCounter {
    _$_mutationCounterAtom.reportRead();
    return super._mutationCounter;
  }

  @override
  set _mutationCounter(int value) {
    _$_mutationCounterAtom.reportWrite(value, super._mutationCounter, () {
      super._mutationCounter = value;
    });
  }

  late final _$historyListAtom =
      Atom(name: '_HistoryCollectStore.historyList', context: context);

  @override
  ObservableList<HistoryItem> get historyList {
    _$historyListAtom.reportRead();
    return super.historyList;
  }

  @override
  set historyList(ObservableList<HistoryItem> value) {
    _$historyListAtom.reportWrite(value, super.historyList, () {
      super.historyList = value;
    });
  }

  late final _$collectListAtom =
      Atom(name: '_HistoryCollectStore.collectList', context: context);

  @override
  ObservableList<CollectItem> get collectList {
    _$collectListAtom.reportRead();
    return super.collectList;
  }

  @override
  set collectList(ObservableList<CollectItem> value) {
    _$collectListAtom.reportWrite(value, super.collectList, () {
      super.collectList = value;
    });
  }

  late final _$trackListAtom =
      Atom(name: '_HistoryCollectStore.trackList', context: context);

  @override
  ObservableList<TrackItem> get trackList {
    _$trackListAtom.reportRead();
    return super.trackList;
  }

  @override
  set trackList(ObservableList<TrackItem> value) {
    _$trackListAtom.reportWrite(value, super.trackList, () {
      super.trackList = value;
    });
  }

  late final _$refreshHistoryMetadataAsyncAction = AsyncAction(
      '_HistoryCollectStore.refreshHistoryMetadata',
      context: context);

  @override
  Future<int> refreshHistoryMetadata() {
    return _$refreshHistoryMetadataAsyncAction
        .run(() => super.refreshHistoryMetadata());
  }

  late final _$addHistoryAsyncAction =
      AsyncAction('_HistoryCollectStore.addHistory', context: context);

  @override
  Future<void> addHistory(HistoryItem item) {
    return _$addHistoryAsyncAction.run(() => super.addHistory(item));
  }

  late final _$clearHistoryAsyncAction =
      AsyncAction('_HistoryCollectStore.clearHistory', context: context);

  @override
  Future<void> clearHistory() {
    return _$clearHistoryAsyncAction.run(() => super.clearHistory());
  }

  late final _$addCollectAsyncAction =
      AsyncAction('_HistoryCollectStore.addCollect', context: context);

  @override
  Future<void> addCollect(CollectItem item) {
    return _$addCollectAsyncAction.run(() => super.addCollect(item));
  }

  late final _$removeCollectAsyncAction =
      AsyncAction('_HistoryCollectStore.removeCollect', context: context);

  @override
  Future<void> removeCollect(String animeUrl) {
    return _$removeCollectAsyncAction.run(() => super.removeCollect(animeUrl));
  }

  late final _$addTrackAsyncAction =
      AsyncAction('_HistoryCollectStore.addTrack', context: context);

  @override
  Future<void> addTrack(TrackItem item) {
    return _$addTrackAsyncAction.run(() => super.addTrack(item));
  }

  late final _$removeTrackAsyncAction =
      AsyncAction('_HistoryCollectStore.removeTrack', context: context);

  @override
  Future<void> removeTrack(String animeUrl) {
    return _$removeTrackAsyncAction.run(() => super.removeTrack(animeUrl));
  }

  late final _$_HistoryCollectStoreActionController =
      ActionController(name: '_HistoryCollectStore', context: context);

  @override
  void loadHistory() {
    final _$actionInfo = _$_HistoryCollectStoreActionController.startAction(
        name: '_HistoryCollectStore.loadHistory');
    try {
      return super.loadHistory();
    } finally {
      _$_HistoryCollectStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void loadCollects() {
    final _$actionInfo = _$_HistoryCollectStoreActionController.startAction(
        name: '_HistoryCollectStore.loadCollects');
    try {
      return super.loadCollects();
    } finally {
      _$_HistoryCollectStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void loadTracks() {
    final _$actionInfo = _$_HistoryCollectStoreActionController.startAction(
        name: '_HistoryCollectStore.loadTracks');
    try {
      return super.loadTracks();
    } finally {
      _$_HistoryCollectStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
historyList: ${historyList},
collectList: ${collectList},
trackList: ${trackList}
    ''';
  }
}

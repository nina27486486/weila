// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HomeStore on _HomeStore, Store {
  late final _$latestListAtom =
      Atom(name: '_HomeStore.latestList', context: context);

  @override
  ObservableList<Map<String, dynamic>> get latestList {
    _$latestListAtom.reportRead();
    return super.latestList;
  }

  @override
  set latestList(ObservableList<Map<String, dynamic>> value) {
    _$latestListAtom.reportWrite(value, super.latestList, () {
      super.latestList = value;
    });
  }

  late final _$trendingListAtom =
      Atom(name: '_HomeStore.trendingList', context: context);

  @override
  ObservableList<Map<String, dynamic>> get trendingList {
    _$trendingListAtom.reportRead();
    return super.trendingList;
  }

  @override
  set trendingList(ObservableList<Map<String, dynamic>> value) {
    _$trendingListAtom.reportWrite(value, super.trendingList, () {
      super.trendingList = value;
    });
  }

  late final _$isLoadingLatestAtom =
      Atom(name: '_HomeStore.isLoadingLatest', context: context);

  @override
  bool get isLoadingLatest {
    _$isLoadingLatestAtom.reportRead();
    return super.isLoadingLatest;
  }

  @override
  set isLoadingLatest(bool value) {
    _$isLoadingLatestAtom.reportWrite(value, super.isLoadingLatest, () {
      super.isLoadingLatest = value;
    });
  }

  late final _$isLoadingTrendingAtom =
      Atom(name: '_HomeStore.isLoadingTrending', context: context);

  @override
  bool get isLoadingTrending {
    _$isLoadingTrendingAtom.reportRead();
    return super.isLoadingTrending;
  }

  @override
  set isLoadingTrending(bool value) {
    _$isLoadingTrendingAtom.reportWrite(value, super.isLoadingTrending, () {
      super.isLoadingTrending = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_HomeStore.errorMessage', context: context);

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

  late final _$loadLatestAsyncAction =
      AsyncAction('_HomeStore.loadLatest', context: context);

  @override
  Future<void> loadLatest() {
    return _$loadLatestAsyncAction.run(() => super.loadLatest());
  }

  late final _$loadTrendingAsyncAction =
      AsyncAction('_HomeStore.loadTrending', context: context);

  @override
  Future<void> loadTrending() {
    return _$loadTrendingAsyncAction.run(() => super.loadTrending());
  }

  late final _$loadAllAsyncAction =
      AsyncAction('_HomeStore.loadAll', context: context);

  @override
  Future<void> loadAll() {
    return _$loadAllAsyncAction.run(() => super.loadAll());
  }

  @override
  String toString() {
    return '''
latestList: ${latestList},
trendingList: ${trendingList},
isLoadingLatest: ${isLoadingLatest},
isLoadingTrending: ${isLoadingTrending}
    ''';
  }
}

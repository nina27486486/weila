class PlayerEpisodeSelection {
  PlayerEpisodeSelection({required int initialIndex})
      : _index = initialIndex < 0 ? 0 : initialIndex;

  int _index;

  int get index => _index;

  int get danmakuEpisodeNumber => _index + 1;

  void select(int index) {
    _index = index < 0 ? 0 : index;
  }
}

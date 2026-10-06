abstract interface class FullscreenController {
  Future<void> setFullscreen(bool enabled);
}

class NoopFullscreenController implements FullscreenController {
  const NoopFullscreenController();

  @override
  Future<void> setFullscreen(bool enabled) async {}
}

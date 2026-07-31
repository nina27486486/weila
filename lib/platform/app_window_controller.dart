abstract interface class AppWindowController {
  Future<void> initialize();
}

class NoopAppWindowController implements AppWindowController {
  const NoopAppWindowController();

  @override
  Future<void> initialize() async {}
}

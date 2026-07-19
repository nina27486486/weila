import 'dart:async';

enum LibraryEventScope { history, collect, track, download }

class LibraryChangedEvent {
  final LibraryEventScope scope;
  final String reason;
  final String? key;
  final DateTime? createdAt;

  const LibraryChangedEvent({
    required this.scope,
    required this.reason,
    this.key,
    this.createdAt,
  });

  LibraryChangedEvent.now({
    required this.scope,
    required this.reason,
    this.key,
  }) : createdAt = DateTime.now();
}

class LibraryEventBus {
  static final LibraryEventBus instance = LibraryEventBus._();

  final StreamController<LibraryChangedEvent> _controller;
  var _disposed = false;

  LibraryEventBus()
      : _controller = StreamController<LibraryChangedEvent>.broadcast();

  LibraryEventBus._()
      : _controller = StreamController<LibraryChangedEvent>.broadcast();

  Stream<LibraryChangedEvent> get stream => _controller.stream;

  Stream<LibraryChangedEvent> streamFor(LibraryEventScope scope) {
    return stream.where((event) => event.scope == scope);
  }

  void publish(LibraryChangedEvent event) {
    if (_disposed) return;
    _controller.add(
      event.createdAt == null
          ? LibraryChangedEvent.now(
              scope: event.scope,
              reason: event.reason,
              key: event.key,
            )
          : event,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}

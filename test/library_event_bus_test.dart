import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/library/library_event_bus.dart';

void main() {
  test('library event bus publishes typed change events', () async {
    final events = LibraryEventBus();
    final received = <LibraryChangedEvent>[];
    final subscription =
        events.streamFor(LibraryEventScope.track).listen(received.add);
    addTearDown(subscription.cancel);
    addTearDown(events.dispose);

    events.publish(const LibraryChangedEvent(
      scope: LibraryEventScope.history,
      reason: 'ignored',
    ));
    events.publish(const LibraryChangedEvent(
      scope: LibraryEventScope.track,
      reason: 'added',
      key: 'anime:1',
    ));

    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single.scope, LibraryEventScope.track);
    expect(received.single.reason, 'added');
    expect(received.single.key, 'anime:1');
  });
}

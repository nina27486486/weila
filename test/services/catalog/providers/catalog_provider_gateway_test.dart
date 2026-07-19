import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/providers/catalog_provider.dart';
import 'package:weila/services/catalog/providers/catalog_provider_gateway.dart';

void main() {
  test('discovery falls back to Jikan only when AniList fails', () async {
    final anilist = _FakeProvider(
      id: 'anilist',
      modes: const {CatalogMode.discovery},
      onQuery: (_) => throw const CatalogProviderException(
        providerId: 'anilist',
        stage: 'request',
        message: 'offline',
      ),
    );
    final jikan = _FakeProvider(
      id: 'jikan',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final gateway = CatalogProviderGateway(
      anilist: anilist,
      jikan: jikan,
    );

    final page = await gateway.query(const CatalogQuery());

    expect(page.complete, isTrue);
    expect(anilist.calls, 1);
    expect(jikan.calls, 1);
  });

  test('a successful empty AniList page does not trigger fallback', () async {
    final anilist = _FakeProvider(
      id: 'anilist',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final jikan = _FakeProvider(
      id: 'jikan',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final gateway = CatalogProviderGateway(anilist: anilist, jikan: jikan);

    await gateway.query(const CatalogQuery());

    expect(anilist.calls, 1);
    expect(jikan.calls, 0);
  });

  test('an explicitly requested provider never falls back to another one',
      () async {
    final anilist = _FakeProvider(
      id: 'anilist',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final jikan = _FakeProvider(
      id: 'jikan',
      modes: const {CatalogMode.discovery},
      onQuery: (_) => throw const CatalogProviderException(
        providerId: 'jikan',
        stage: 'request',
        message: 'offline',
      ),
    );
    final gateway = CatalogProviderGateway(anilist: anilist, jikan: jikan);

    await expectLater(
      gateway.query(const CatalogQuery(providerId: 'jikan')),
      throwsA(isA<CatalogProviderException>()),
    );

    expect(anilist.calls, 0);
    expect(jikan.calls, 1);
  });

  test('playable aggregate keeps source cursors and exposes partial errors',
      () async {
    final anilist = _FakeProvider(
      id: 'anilist',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final jikan = _FakeProvider(
      id: 'jikan',
      modes: const {CatalogMode.discovery},
      result: const ProviderCatalogPage(complete: true),
    );
    final sourceA = _FakeProvider(
      id: 'cms_a',
      modes: const {CatalogMode.playable},
      onQuery: (query) async => ProviderCatalogPage(
        items: [_content('a-${sourceAPlaceholder(query.cursor)}')],
        nextCursor: query.cursor == null ? 'a-next' : null,
        complete: query.cursor != null,
        remotelyEvaluated: const {'providerId'},
      ),
    );
    final sourceB = _FakeProvider(
      id: 'cms_b',
      modes: const {CatalogMode.playable},
      onQuery: (_) => throw const CatalogProviderException(
        providerId: 'cms_b',
        stage: 'list',
        message: 'offline',
      ),
    );
    final gateway = CatalogProviderGateway(
      anilist: anilist,
      jikan: jikan,
      playableProviders: [sourceA, sourceB],
    );

    final first = await gateway.query(
      const CatalogQuery(mode: CatalogMode.playable),
    );
    final second = await gateway.query(
      CatalogQuery(mode: CatalogMode.playable, cursor: first.nextCursor),
    );

    expect(first.items.single.titles.primary, 'a-first');
    expect(first.warnings.single, contains('cms_b'));
    expect(first.toCatalogPage(CatalogMode.playable).warning, contains('部分片源'));
    expect(first.complete, isFalse);
    expect(sourceA.queries.first.providerId, 'cms_a');
    expect(sourceA.queries.last.cursor, 'a-next');
    expect(second.items.single.titles.primary, 'a-next');
  });

  test('disabled or missing exact playable providers fail without substitution',
      () async {
    final gateway = CatalogProviderGateway(
      anilist: _FakeProvider(
        id: 'anilist',
        modes: const {CatalogMode.discovery},
        result: const ProviderCatalogPage(complete: true),
      ),
      jikan: _FakeProvider(
        id: 'jikan',
        modes: const {CatalogMode.discovery},
        result: const ProviderCatalogPage(complete: true),
      ),
    );

    await expectLater(
      gateway.query(const CatalogQuery(mode: CatalogMode.playable)),
      throwsA(isA<CatalogProvidersDisabledException>()),
    );
    await expectLater(
      gateway.query(
        const CatalogQuery(
          mode: CatalogMode.playable,
          providerId: 'cms_missing',
        ),
      ),
      throwsA(isA<CatalogProviderUnavailableException>()),
    );
  });
}

String sourceAPlaceholder(String? cursor) => cursor == null ? 'first' : 'next';

CatalogContent _content(String title) => CatalogContent(
      contentId: '',
      titles: CatalogTitles(primary: title),
    );

class _FakeProvider implements CatalogProvider {
  _FakeProvider({
    required this.id,
    required Set<CatalogMode> modes,
    this.result,
    this.onQuery,
  }) : capabilities = CatalogProviderCapabilities(modes: modes);

  final String id;
  final ProviderCatalogPage? result;
  final Future<ProviderCatalogPage> Function(CatalogQuery query)? onQuery;
  final List<CatalogQuery> queries = [];
  int calls = 0;

  @override
  String get providerId => id;

  @override
  final CatalogProviderCapabilities capabilities;

  @override
  Future<ProviderCatalogPage> query(CatalogQuery query) async {
    calls++;
    queries.add(query);
    final callback = onQuery;
    if (callback != null) return callback(query);
    return result!;
  }
}

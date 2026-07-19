import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/models/plugin_catalog.dart';
import 'package:weila/services/plugin/plugin_service.dart';

void main() {
  group('plugin catalog capability', () {
    test('valid catalog JSON round-trips without a Hive type id', () {
      final plugin = _plugin(
        catalog: const PluginCatalogConfig(
          kind: 'mac_cms_v1',
          categories: [
            PluginCatalogCategory(
              id: '10',
              label: '日本动漫',
              facets: {'region': 'jp'},
            ),
          ],
          sorts: {'updated', 'score', 'popularity'},
        ),
      );

      final decoded = Plugin.fromJson(plugin.toJson());

      expect(decoded.catalog, plugin.catalog);
      expect(decoded.toJson()['catalog'], plugin.catalog!.toJson());
    });

    test('invalid optional catalog config safely degrades to null', () {
      final json = _plugin().toJson()
        ..['catalog'] = {
          'kind': 'unknown_kind',
          'categories': [
            {
              'id': '10',
              'label': '日本动漫',
              'facets': {'region': 'moon'},
            },
          ],
          'sorts': ['updated', 'unsupported'],
        };

      expect(Plugin.fromJson(json).catalog, isNull);
      expect(
        PluginCatalogConfig.tryFromJson({
          'kind': 'mac_cms_v1',
          'categories': [
            {'id': '10', 'label': ''},
          ],
        }),
        isNull,
      );
    });

    test('new adapter reads legacy thirteen-field records with catalog null',
        () {
      final reader = _QueueBinaryReader(
        bytes: [13, for (var index = 0; index < 13; index++) index],
        values: const [
          'legacy_api',
          'Legacy',
          '1.2.3',
          'https://legacy.example',
          '/search',
          'list',
          'name',
          'result',
          'roads',
          'chapters',
          'agent',
          'https://legacy.example/',
          false,
        ],
      );

      final plugin = PluginAdapter().read(reader);

      expect(plugin.api, 'legacy_api');
      expect(plugin.enabled, isFalse);
      expect(plugin.catalog, isNull);
    });

    test('built-in CMS configs expose normalized categories and sorts', () {
      final yinhua = PluginCatalogDefaults.forPlugin(
        'cms_yinhua',
        'https://www.yinhuadm.xyz',
      );
      final ffzy = PluginCatalogDefaults.forPlugin(
        'cms_ffzy',
        'https://cj.ffzyapi.com',
      );

      expect(
        yinhua!.categories.map((category) => category.id),
        ['10', '9', '11', '12'],
      );
      expect(yinhua.categories.first.facets, {'region': 'jp'});
      expect(
          ffzy!.categories.map((category) => category.id), ['30', '29', '31']);
      expect(ffzy.sorts, {'updated', 'score', 'popularity'});
      expect(
        PluginCatalogDefaults.forPlugin(
          'cms_yinhua',
          'https://custom.example',
        ),
        isNull,
      );
    });

    test('only enabled plugins with valid catalog config are catalog capable',
        () {
      final enabled = _plugin(
        api: 'cms_enabled',
        catalog: const PluginCatalogConfig(
          kind: 'mac_cms_v1',
          categories: [
            PluginCatalogCategory(id: '1', label: '动画'),
          ],
        ),
      );
      final disabled = _plugin(
        api: 'cms_disabled',
        enabled: false,
        catalog: enabled.catalog,
      );
      final legacy = _plugin(api: 'cms_legacy');

      expect(
        PluginService.enabledCatalogPlugins([enabled, disabled, legacy])
            .map((plugin) => plugin.api),
        ['cms_enabled'],
      );
      expect(
        PluginService.findEnabledCatalogPlugin(
          [enabled, disabled, legacy],
          'cms_disabled',
        ),
        isNull,
      );
    });
  });
}

Plugin _plugin({
  String api = 'cms_test',
  bool enabled = true,
  PluginCatalogConfig? catalog,
}) {
  return Plugin(
    api: api,
    name: api,
    baseUrl: 'https://example.com',
    searchURL: 'https://example.com/api.php/provide/vod/?ac=videolist',
    searchList: 'list',
    searchName: 'vod_name',
    searchResult: 'vod_id',
    chapterRoads: '',
    chapterResult: '',
    enabled: enabled,
    catalog: catalog,
  );
}

class _QueueBinaryReader implements BinaryReader {
  _QueueBinaryReader({required List<int> bytes, required List<Object?> values})
      : _bytes = List<int>.from(bytes),
        _values = List<Object?>.from(values);

  final List<int> _bytes;
  final List<Object?> _values;

  @override
  int readByte() => _bytes.removeAt(0);

  @override
  dynamic read([int? typeId]) => _values.removeAt(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

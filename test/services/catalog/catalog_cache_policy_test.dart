import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/catalog/catalog_cache_policy.dart';

void main() {
  test('catalog cache defaults expose the required durations', () {
    expect(catalogDiscoveryMetadataTtl, const Duration(hours: 24));
    expect(catalogCmsListTtl, const Duration(minutes: 30));
    expect(catalogPlayableBindingTtl, const Duration(hours: 6));
  });
}

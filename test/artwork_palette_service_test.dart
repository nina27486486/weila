import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/artwork_palette_service.dart';
import 'package:weila/widgets/cover_image.dart';

Uint8List _pixels(List<Color> colors) {
  return Uint8List.fromList([
    for (final color in colors) ...[
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      (color.a * 255).round(),
    ],
  ]);
}

void main() {
  test('封面取色过滤透明、近白和近黑像素并提取主辅色', () {
    final palette = ArtworkPaletteExtractor.fromRgba(
      _pixels([
        ...List.filled(8, const Color(0xFFE66F86)),
        ...List.filled(4, const Color(0xFF4C9FD8)),
        Colors.transparent,
        Colors.white,
        Colors.black,
      ]),
    );

    expect(palette.primary.r, greaterThan(palette.primary.b));
    expect(palette.secondary.b, greaterThan(palette.secondary.r));
    expect(palette.foreground, Colors.white);
  });

  test('无有效像素时返回天空与樱花回退色', () {
    final palette = ArtworkPaletteExtractor.fromRgba(
      _pixels([Colors.transparent, Colors.white, Colors.black]),
    );

    expect(palette, ArtworkPalette.fallback);
  });

  test('相同封面请求会合并并使用内存缓存', () async {
    var loads = 0;
    final completer = Completer<Uint8List>();
    final service = ArtworkPaletteService(
      pixelLoader: (_) {
        loads++;
        return completer.future;
      },
    );
    final provider = MemoryImage(Uint8List(0));

    final first = service.resolve(cacheKey: 'cover:a', provider: provider);
    final second = service.resolve(cacheKey: 'cover:a', provider: provider);
    completer.complete(_pixels(List.filled(4, const Color(0xFF4C9FD8))));

    expect(await first, await second);
    expect(loads, 1);

    await service.resolve(cacheKey: 'cover:a', provider: provider);
    expect(loads, 1);
  });

  test('LRU 缓存在达到容量后淘汰最久未使用的封面', () async {
    var loads = 0;
    final service = ArtworkPaletteService(
      cacheCapacity: 2,
      pixelLoader: (_) async {
        loads++;
        return _pixels(List.filled(4, const Color(0xFF4C9FD8)));
      },
    );
    final provider = MemoryImage(Uint8List(0));

    await service.resolve(cacheKey: 'a', provider: provider);
    await service.resolve(cacheKey: 'b', provider: provider);
    await service.resolve(cacheKey: 'a', provider: provider);
    await service.resolve(cacheKey: 'c', provider: provider);
    await service.resolve(cacheKey: 'b', provider: provider);

    expect(loads, 4);
  });

  test('图片解码失败时安全回退', () async {
    final service = ArtworkPaletteService(
      pixelLoader: (_) async => throw StateError('broken image'),
    );

    final palette = await service.resolve(
      cacheKey: 'broken',
      provider: MemoryImage(Uint8List(0)),
    );

    expect(palette, ArtworkPalette.fallback);
  });

  test('连续解码失败产生的回退缓存同样遵守 LRU 容量', () async {
    final service = ArtworkPaletteService(
      cacheCapacity: 2,
      pixelLoader: (_) async => throw StateError('broken image'),
    );
    final provider = MemoryImage(Uint8List(0));

    await service.resolve(cacheKey: 'broken:a', provider: provider);
    await service.resolve(cacheKey: 'broken:b', provider: provider);
    await service.resolve(cacheKey: 'broken:c', provider: provider);

    expect(service.cachedEntryCount, 2);
  });

  test('封面组件与取色服务复用同一个图片 Provider 规则', () {
    final provider = CoverImage.providerFor('//example.com/poster.jpg');

    expect(provider, isA<CachedNetworkImageProvider>());
    expect(
      (provider! as CachedNetworkImageProvider).url,
      'https://example.com/poster.jpg',
    );
    expect(CoverImage.providerFor(null), isNull);
  });
}

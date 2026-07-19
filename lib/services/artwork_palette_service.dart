import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class ArtworkPalette {
  final Color primary;
  final Color secondary;
  final Color foreground;

  const ArtworkPalette({
    required this.primary,
    required this.secondary,
    required this.foreground,
  });

  static const fallback = ArtworkPalette(
    primary: Color(0xFF3699DB),
    secondary: Color(0xFFEFA7BA),
    foreground: Colors.white,
  );

  @override
  bool operator ==(Object other) {
    return other is ArtworkPalette &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.foreground == foreground;
  }

  @override
  int get hashCode => Object.hash(primary, secondary, foreground);
}

class ArtworkPaletteExtractor {
  const ArtworkPaletteExtractor._();

  static ArtworkPalette fromRgba(Uint8List bytes) {
    if (bytes.length < 4) return ArtworkPalette.fallback;

    final buckets = <int, _ColorBucket>{};
    for (var offset = 0; offset + 3 < bytes.length; offset += 4) {
      final red = bytes[offset];
      final green = bytes[offset + 1];
      final blue = bytes[offset + 2];
      final alpha = bytes[offset + 3];
      if (alpha < 128) continue;

      final highest = [red, green, blue].reduce((a, b) => a > b ? a : b);
      final lowest = [red, green, blue].reduce((a, b) => a < b ? a : b);
      if (highest <= 24 || lowest >= 242) continue;

      final key = ((red >> 5) << 10) | ((green >> 5) << 5) | (blue >> 5);
      buckets.putIfAbsent(key, _ColorBucket.new).add(red, green, blue);
    }

    if (buckets.isEmpty) return ArtworkPalette.fallback;

    final ranked = buckets.values.toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    final primary = ranked.first.color;
    var secondary = ArtworkPalette.fallback.secondary;
    for (final candidate in ranked.skip(1)) {
      if (_distanceSquared(primary, candidate.color) >= 2500) {
        secondary = candidate.color;
        break;
      }
    }

    return ArtworkPalette(
      primary: primary,
      secondary: secondary,
      foreground: primary.computeLuminance() > 0.48
          ? const Color(0xFF172235)
          : Colors.white,
    );
  }

  static int _distanceSquared(Color first, Color second) {
    final red = ((first.r - second.r) * 255).round();
    final green = ((first.g - second.g) * 255).round();
    final blue = ((first.b - second.b) * 255).round();
    return red * red + green * green + blue * blue;
  }
}

typedef ArtworkPixelLoader = Future<Uint8List> Function(
  ImageProvider<Object> provider,
);

class ArtworkPaletteService {
  final int cacheCapacity;
  final ArtworkPixelLoader _pixelLoader;
  final LinkedHashMap<String, ArtworkPalette> _cache = LinkedHashMap();
  final Map<String, Future<ArtworkPalette>> _pending = {};

  ArtworkPaletteService({
    this.cacheCapacity = 64,
    ArtworkPixelLoader? pixelLoader,
  })  : assert(cacheCapacity > 0),
        _pixelLoader = pixelLoader ?? _loadPixels;

  static final shared = ArtworkPaletteService();

  Future<ArtworkPalette> resolve({
    required String cacheKey,
    required ImageProvider<Object> provider,
  }) {
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return SynchronousFuture(cached);
    }

    final active = _pending[cacheKey];
    if (active != null) return active;

    final request = _resolveAndCache(cacheKey, provider);
    _pending[cacheKey] = request;
    return request;
  }

  Future<ArtworkPalette> _resolveAndCache(
    String cacheKey,
    ImageProvider<Object> provider,
  ) async {
    try {
      final pixels = await _pixelLoader(provider);
      final palette = ArtworkPaletteExtractor.fromRgba(pixels);
      _store(cacheKey, palette);
      return palette;
    } catch (_) {
      _store(cacheKey, ArtworkPalette.fallback);
      return ArtworkPalette.fallback;
    } finally {
      _pending.remove(cacheKey);
    }
  }

  void _store(String cacheKey, ArtworkPalette palette) {
    _cache.remove(cacheKey);
    _cache[cacheKey] = palette;
    while (_cache.length > cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  @visibleForTesting
  int get cachedEntryCount => _cache.length;

  static Future<Uint8List> _loadPixels(
    ImageProvider<Object> provider,
  ) async {
    final resized = ResizeImage.resizeIfNeeded(48, 48, provider);
    final stream = resized.resolve(ImageConfiguration.empty);
    final completer = Completer<Uint8List>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) async {
        stream.removeListener(listener);
        try {
          final data = await info.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) {
            throw StateError('Unable to read cover pixels.');
          }
          completer.complete(data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ));
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

class _ColorBucket {
  var count = 0;
  var red = 0;
  var green = 0;
  var blue = 0;

  void add(int nextRed, int nextGreen, int nextBlue) {
    count++;
    red += nextRed;
    green += nextGreen;
    blue += nextBlue;
  }

  Color get color => Color.fromARGB(
        255,
        (red / count).round(),
        (green / count).round(),
        (blue / count).round(),
      );

  int get score {
    final average = color;
    final highest =
        [average.r, average.g, average.b].reduce((a, b) => a > b ? a : b);
    final lowest =
        [average.r, average.g, average.b].reduce((a, b) => a < b ? a : b);
    final saturation = ((highest - lowest) * 255).round();
    return count * (256 + saturation);
  }
}

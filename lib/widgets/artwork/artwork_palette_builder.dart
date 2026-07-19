import 'package:flutter/material.dart';

import '../../services/artwork_palette_service.dart';

export '../../services/artwork_palette_service.dart';

class ArtworkPaletteBuilder extends StatefulWidget {
  final String cacheKey;
  final ImageProvider<Object> provider;
  final ArtworkPaletteService? service;
  final Widget Function(BuildContext context, ArtworkPalette palette) builder;

  const ArtworkPaletteBuilder({
    super.key,
    required this.cacheKey,
    required this.provider,
    required this.builder,
    this.service,
  });

  @override
  State<ArtworkPaletteBuilder> createState() => _ArtworkPaletteBuilderState();
}

class _ArtworkPaletteBuilderState extends State<ArtworkPaletteBuilder> {
  ArtworkPalette _palette = ArtworkPalette.fallback;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtworkPaletteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.provider != widget.provider ||
        oldWidget.service != widget.service) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    final palette =
        await (widget.service ?? ArtworkPaletteService.shared).resolve(
      cacheKey: widget.cacheKey,
      provider: widget.provider,
    );
    if (!mounted || generation != _generation) return;
    setState(() => _palette = palette);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}

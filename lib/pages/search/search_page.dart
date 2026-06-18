import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../stores/anime_store.dart';
import '../../models/anime.dart';
import '../../services/plugin/plugin_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/cover_image.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _store = AnimeStore();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _store.search(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _doSearch() {
    _debounce?.cancel();
    final keyword = _controller.text.trim();
    if (keyword.isNotEmpty) {
      _store.search(keyword);
      _focusNode.unfocus();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final keyword = _controller.text.trim(); // 从 controller 读最新值
      if (keyword.isNotEmpty) {
        _store.search(keyword);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.pop(),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '搜索番剧、动画电影、人物...',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _doSearch(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _doSearch,
            child: const Text('搜索', style: TextStyle(color: AppTheme.primaryBlue)),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (_store.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  SizedBox(height: 16),
                  Text('正在搜索...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          if (_store.errorMessage != null && _store.searchResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    _store.errorMessage!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请检查插件配置或更换关键词',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          if (_store.searchResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    '输入关键词开始搜索',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已启用 ${PluginService().getEnabledPlugins().length} 个插件',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _store.searchResults.length,
            itemBuilder: (context, index) {
              final anime = _store.searchResults[index];
              return _SearchResultCard(
                anime: anime,
                onTap: () {
                  Modular.to.pushNamed(
                    '/detail?url=${Uri.encodeComponent(anime.url)}&name=${Uri.encodeComponent(anime.name)}',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback onTap;

  const _SearchResultCard({required this.anime, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering ? AppTheme.bgHover : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? AppTheme.primaryBlue.withValues(alpha: 0.3) : Colors.transparent,
            ),
            boxShadow: _hovering
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            children: [
              // 封面
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 106,
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: CoverImage(url: widget.anime.cover, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: _hovering ? AppTheme.primaryBlue : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(widget.anime.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 6),
                    if (widget.anime.description != null && widget.anime.description!.isNotEmpty)
                      Text(
                        widget.anime.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.tagBg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            widget.anime.sourcePlugin,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 播放图标
              AnimatedOpacity(
                opacity: _hovering ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.play_circle_outline, size: 32, color: AppTheme.primaryBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

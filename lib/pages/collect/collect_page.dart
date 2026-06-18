import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../theme/app_theme.dart';
import '../../stores/history_collect_store.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadCollects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        title: const Text('我的收藏', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Observer(
        builder: (_) {
          if (_store.collectList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('暂无收藏', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('收藏喜欢的番剧，下次再看', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: _store.collectList.length,
            itemBuilder: (context, index) {
              final item = _store.collectList[index];
              return _CollectCard(
                item: item,
                onTap: () {
                  Modular.to.pushNamed(
                    '/detail?url=${Uri.encodeComponent(item.animeUrl)}'
                    '&name=${Uri.encodeComponent(item.animeName)}',
                  );
                },
                onRemove: () async {
                  await _store.removeCollect(item.animeUrl);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CollectCard extends StatefulWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CollectCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_CollectCard> createState() => _CollectCardState();
}

class _CollectCardState extends State<_CollectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? AppTheme.primaryBlue.withValues(alpha: 0.4) : AppTheme.divider,
            ),
            boxShadow: _hovering
                ? [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.15), blurRadius: 12)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: item.cover != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              child: Image.network(
                                item.cover!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.movie_outlined, size: 40, color: AppTheme.textMuted),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.movie_outlined, size: 40, color: AppTheme.textMuted),
                            ),
                    ),
                    // 移除按钮
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: widget.onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white70),
                        ),
                      ),
                    ),
                    // 来源标签
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.sourcePlugin,
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  item.animeName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_state_view.dart';

@immutable
class CatalogFilterOption {
  final String id;
  final String label;

  const CatalogFilterOption({required this.id, required this.label});
}

class AnimeCatalogView extends StatelessWidget {
  final String title;
  final String description;
  final List<CatalogFilterOption> sourceOptions;
  final String? selectedSourceId;
  final ValueChanged<String>? onSourceSelected;
  final List<CatalogFilterOption> categoryOptions;
  final String? selectedCategoryId;
  final ValueChanged<String>? onCategorySelected;
  final List<CatalogFilterOption> genreOptions;
  final String? selectedGenreId;
  final ValueChanged<String>? onGenreSelected;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final ValueChanged<Map<String, dynamic>> onOpenAnime;
  final VoidCallback onRetry;
  final ScrollController? scrollController;

  const AnimeCatalogView({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    required this.onOpenAnime,
    required this.onRetry,
    this.sourceOptions = const [],
    this.selectedSourceId,
    this.onSourceSelected,
    this.categoryOptions = const [],
    this.selectedCategoryId,
    this.onCategorySelected,
    this.genreOptions = const [],
    this.selectedGenreId,
    this.onGenreSelected,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: _CatalogIntroduction(
              title: title,
              description: description,
              itemCount: items.length,
            ),
          ),
        ),
        if (sourceOptions.isNotEmpty ||
            categoryOptions.isNotEmpty ||
            genreOptions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 26),
              child: _CatalogFilters(
                sourceOptions: sourceOptions,
                selectedSourceId: selectedSourceId,
                onSourceSelected: onSourceSelected,
                categoryOptions: categoryOptions,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: onCategorySelected,
                genreOptions: genreOptions,
                selectedGenreId: selectedGenreId,
                onGenreSelected: onGenreSelected,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34, bottom: 16),
            child: _ResultHeading(itemCount: items.length),
          ),
        ),
        if (isLoading && items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.loading(
              title: '正在翻阅片库',
              message: '片源与作品信息正在汇合。',
            ),
          )
        else if (errorMessage != null && items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.error(
              title: '片库暂时没有回应',
              message: errorMessage!,
              onRetry: onRetry,
            ),
          )
        else if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.empty(
              title: '这一格还是空白',
              message: '换一个片源或筛选条件再看看。',
            ),
          )
        else
          SliverPadding(
            key: const ValueKey('catalog-results-grid'),
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 218,
                mainAxisExtent: 326,
                crossAxisSpacing: 16,
                mainAxisSpacing: 22,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _CatalogAnimeCard(
                  index: index,
                  item: item,
                  onTap: () => onOpenAnime(item),
                );
              },
            ),
          ),
        if (isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.sky,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CatalogIntroduction extends StatelessWidget {
  final String title;
  final String description;
  final int itemCount;

  const _CatalogIntroduction({
    required this.title,
    required this.description,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 32, height: 1, color: colors.sakura),
                    const SizedBox(width: 10),
                    Text(
                      '发现下一段故事',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 118,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemCount.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colors.sky,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '当前结果',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilters extends StatelessWidget {
  final List<CatalogFilterOption> sourceOptions;
  final String? selectedSourceId;
  final ValueChanged<String>? onSourceSelected;
  final List<CatalogFilterOption> categoryOptions;
  final String? selectedCategoryId;
  final ValueChanged<String>? onCategorySelected;
  final List<CatalogFilterOption> genreOptions;
  final String? selectedGenreId;
  final ValueChanged<String>? onGenreSelected;

  const _CatalogFilters({
    required this.sourceOptions,
    required this.selectedSourceId,
    required this.onSourceSelected,
    required this.categoryOptions,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.genreOptions,
    required this.selectedGenreId,
    required this.onGenreSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Column(
        children: [
          if (sourceOptions.isNotEmpty)
            _FilterLine(
              label: '片源',
              options: sourceOptions,
              selectedId: selectedSourceId,
              onSelected: onSourceSelected,
            ),
          if (sourceOptions.isNotEmpty && categoryOptions.isNotEmpty)
            Divider(height: 1, color: context.colors.divider),
          if (categoryOptions.isNotEmpty)
            _FilterLine(
              label: '栏目',
              options: categoryOptions,
              selectedId: selectedCategoryId,
              onSelected: onCategorySelected,
            ),
          if ((sourceOptions.isNotEmpty || categoryOptions.isNotEmpty) &&
              genreOptions.isNotEmpty)
            Divider(height: 1, color: context.colors.divider),
          if (genreOptions.isNotEmpty)
            _FilterLine(
              label: '类型',
              options: genreOptions,
              selectedId: selectedGenreId,
              onSelected: onGenreSelected,
            ),
        ],
      ),
    );
  }
}

class _FilterLine extends StatelessWidget {
  final String label;
  final List<CatalogFilterOption> options;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  const _FilterLine({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.colors.textMuted,
                    ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in options)
                  _FilterChoice(
                    option: option,
                    selected: option.id == selectedId,
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(option.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatefulWidget {
  final CatalogFilterOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterChoice({
    required this.option,
    required this.selected,
    this.onTap,
  });

  @override
  State<_FilterChoice> createState() => _FilterChoiceState();
}

class _FilterChoiceState extends State<_FilterChoice> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.option.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.skyLight
                  : _hovered
                      ? colors.bgHover
                      : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? colors.sky : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Text(
              widget.option.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.selected || _hovered
                        ? colors.sky
                        : colors.textSecondary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  final int itemCount;

  const _ResultHeading({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 28, color: context.colors.sky),
        const SizedBox(width: 10),
        Text('片单', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(width: 10),
        Text(
          '共 $itemCount 部作品',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CatalogAnimeCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _CatalogAnimeCard({
    required this.index,
    required this.item,
    required this.onTap,
  });

  @override
  State<_CatalogAnimeCard> createState() => _CatalogAnimeCardState();
}

class _CatalogAnimeCardState extends State<_CatalogAnimeCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = widget.item['name']?.toString() ?? '未命名作品';
    final status = widget.item['status']?.toString() ?? '';
    final genres = _genresOf(widget.item);
    final score = _scoreOf(widget.item);

    return Semantics(
      button: true,
      label: '查看$name',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(
                color: _hovered
                    ? colors.sky.withValues(alpha: 0.58)
                    : colors.divider,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(
                        url: widget.item['cover']?.toString(),
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 9,
                        top: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          color: colors.paper.withValues(alpha: 0.92),
                          child: Text(
                            '${widget.index + 1}'.padLeft(2, '0'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.sky,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                      if (score != null)
                        Positioned(
                          right: 9,
                          top: 9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            color: Colors.black.withValues(alpha: 0.62),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: colors.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  score.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        genres.isEmpty ? status : genres.take(2).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _genresOf(Map<String, dynamic> item) {
  final raw = item['genres'];
  if (raw is! List) return const [];
  return raw.map((entry) => entry.toString()).toList(growable: false);
}

double? _scoreOf(Map<String, dynamic> item) {
  final raw = item['score'];
  return raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
}

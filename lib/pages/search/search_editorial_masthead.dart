import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';

class SearchEditorialMasthead extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String query;
  final bool isLoading;
  final int enabledPluginCount;
  final List<String> history;
  final List<String> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onKeywordTap;
  final ValueChanged<String> onHistoryRemove;
  final VoidCallback onHistoryClear;

  const SearchEditorialMasthead({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.query,
    required this.isLoading,
    required this.enabledPluginCount,
    required this.history,
    required this.suggestions,
    required this.onSearch,
    required this.onChanged,
    required this.onClearSearch,
    required this.onKeywordTap,
    required this.onHistoryRemove,
    required this.onHistoryClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          '从一个名字开始',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.sky,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '搜索动画',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 40,
                              ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '支持中文名、原名、别名与关键词，在多个片源之间寻找可播放内容。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.paper,
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: enabledPluginCount > 0
                            ? colors.success
                            : colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$enabledPluginCount 个片源已连接',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final hasText = controller.text.trim().isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      key: const ValueKey('search-editorial-field'),
                      duration: const Duration(milliseconds: 160),
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.paper,
                        border: Border(
                          top: BorderSide(color: colors.divider),
                          left: BorderSide(color: colors.divider),
                          right: BorderSide(color: colors.divider),
                          bottom: BorderSide(
                            color: focused ? colors.sky : colors.divider,
                            width: focused ? 2 : 1,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16),
                        decoration: InputDecoration(
                          filled: false,
                          hintText: '输入番剧名、别名或关键词',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: focused ? colors.sky : colors.textMuted,
                          ),
                          suffixIcon: hasText
                              ? _ClearSearchButton(onTap: onClearSearch)
                              : const _ShortcutLabel(),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                        ),
                        onChanged: onChanged,
                        onSubmitted: (_) => onSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSearch,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(142, 64),
                        shape: const RoundedRectangleBorder(),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('开始寻找'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (history.isNotEmpty)
            _KeywordTrack(
              label: '最近搜索',
              keywords: history,
              onTap: onKeywordTap,
              onRemove: onHistoryRemove,
              trailingLabel: '清空记录',
              onTrailingTap: onHistoryClear,
            )
          else
            _KeywordTrack(
              label: '编辑推荐',
              keywords: suggestions,
              onTap: onKeywordTap,
            ),
          const SizedBox(height: 22),
          Divider(height: 1, color: colors.divider),
        ],
      ),
    );
  }
}

class _KeywordTrack extends StatelessWidget {
  final String label;
  final List<String> keywords;
  final ValueChanged<String> onTap;
  final ValueChanged<String>? onRemove;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const _KeywordTrack({
    required this.label,
    required this.keywords,
    required this.onTap,
    this.onRemove,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final keyword in keywords)
                _KeywordItem(
                  keyword: keyword,
                  onTap: () => onTap(keyword),
                  onRemove: onRemove == null ? null : () => onRemove!(keyword),
                ),
            ],
          ),
        ),
        if (trailingLabel != null)
          TextButton(
            onPressed: onTrailingTap,
            child: Text(trailingLabel!),
          ),
      ],
    );
  }
}

class _KeywordItem extends StatefulWidget {
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _KeywordItem({
    required this.keyword,
    required this.onTap,
    this.onRemove,
  });

  @override
  State<_KeywordItem> createState() => _KeywordItemState();
}

class _KeywordItemState extends State<_KeywordItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '搜索${widget.keyword}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(
              left: 9,
              right: widget.onRemove == null ? 9 : 4,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: _hovered ? colors.bgHover : Colors.transparent,
              border: Border.all(
                color: _hovered ? colors.sky : colors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.keyword,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _hovered ? colors.sky : colors.textSecondary,
                      ),
                ),
                if (widget.onRemove != null) ...[
                  const SizedBox(width: 3),
                  Tooltip(
                    message: '移除${widget.keyword}',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onRemove,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearSearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '清空搜索',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ),
    );
  }
}

class _ShortcutLabel extends StatelessWidget {
  const _ShortcutLabel();

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          border: Border.all(color: context.colors.divider),
        ),
        child: Text(
          'Ctrl K',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

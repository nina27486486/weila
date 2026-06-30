import '../theme/vira_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class TopSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onNotificationTap;

  const TopSearchBar({
    super.key,
    this.controller,
    this.onSearch,
    this.onHistoryTap,
    this.onDownloadTap,
    this.onNotificationTap,
  });

  @override
  State<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends State<TopSearchBar> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () {
      final keyword = value.trim();
      if (keyword.isNotEmpty && widget.onSearch != null) {
        widget.onSearch!(keyword);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: context.colors.bgDark,
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: widget.controller,
                style:
                    TextStyle(color: context.colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索番剧、动画电影、人物...',
                  hintStyle:
                      TextStyle(color: context.colors.textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: context.colors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onChanged,
                onSubmitted: widget.onSearch,
              ),
            ),
          ),

          SizedBox(width: 16),

          // 历史
          IconButton(
            icon: Icon(Icons.history, size: 22),
            color: context.colors.textSecondary,
            tooltip: '观看历史',
            onPressed: widget.onHistoryTap,
          ),

          // 下载
          IconButton(
            icon: Icon(Icons.download_outlined, size: 22),
            color: context.colors.textSecondary,
            tooltip: '下载管理',
            onPressed: widget.onDownloadTap,
          ),

          // 通知
          IconButton(
            icon: Icon(Icons.notifications_none, size: 22),
            color: context.colors.textSecondary,
            tooltip: '通知',
            onPressed: widget.onNotificationTap,
          ),

          SizedBox(width: 8),

          // 用户头像
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class TopSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onNotificationTap;

  const TopSearchBar({
    super.key,
    this.controller,
    this.onSearch,
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
    _debounce = Timer(const Duration(seconds: 3), () {
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
      color: AppTheme.bgDark,
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '搜索番剧、动画电影、人物...',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onChanged,
                onSubmitted: widget.onSearch,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 历史
          IconButton(
            icon: const Icon(Icons.history, size: 22),
            color: AppTheme.textSecondary,
            tooltip: '观看历史',
            onPressed: () {},
          ),
          
          // 下载
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 22),
            color: AppTheme.textSecondary,
            tooltip: '下载管理',
            onPressed: () {},
          ),
          
          // 通知
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 22),
            color: AppTheme.textSecondary,
            tooltip: '通知',
            onPressed: widget.onNotificationTap,
          ),
          
          const SizedBox(width: 8),
          
          // 用户头像
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

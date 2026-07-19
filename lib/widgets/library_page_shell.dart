import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/vira_colors.dart';

class LibraryPageShell extends StatelessWidget {
  const LibraryPageShell({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha: 0.16),
                      context.colors.bgCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: '返回首页',
                      child: IconButton(
                        mouseCursor: SystemMouseCursors.click,
                        onPressed: onBack,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(icon, color: AppTheme.accentBlue, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: context.colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

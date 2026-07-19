import 'package:flutter/material.dart';

/// 区块标题 - "本季新番" / "热门推荐" 等
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMore;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const Spacer(),
          if (onMore != null)
            TextButton.icon(
              onPressed: onMore,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('查看全部'),
            ),
        ],
      ),
    );
  }
}

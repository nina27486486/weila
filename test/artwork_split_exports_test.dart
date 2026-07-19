import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/artwork/artwork_card.dart';
import 'package:weila/widgets/artwork/artwork_models.dart';
import 'package:weila/widgets/artwork/artwork_palette_builder.dart';
import 'package:weila/widgets/artwork/artwork_surfaces.dart';
import 'package:weila/widgets/artwork/expandable_tool_tabs.dart';
import 'package:weila/widgets/artwork/layered_artwork_stack.dart';
import 'package:weila/widgets/artwork/poster_rail.dart';

void main() {
  testWidgets('artwork 子模块可以独立导入并组合使用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AmbientArtworkBackdrop(
          palette: ArtworkPalette.fallback,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: ArtworkCardSurface(
                    id: 'card',
                    semanticLabel: '打开卡片',
                    onOpen: () {},
                    contentBuilder: (_, __) => const SizedBox.expand(),
                  ),
                ),
                LayeredArtworkStack(
                  items: const [
                    ArtworkStackItem(
                      id: 'stack',
                      title: 'Stack',
                      subtitle: 'Item',
                      imageUrl: null,
                    ),
                  ],
                  onOpen: (_) {},
                ),
                PosterRail(
                  items: const [
                    PosterRailItem(
                      id: 'poster',
                      title: 'Poster',
                      imageUrl: null,
                    ),
                  ],
                  onOpen: (_) {},
                ),
                ExpandableToolTabs(
                  items: const [
                    ExpandableToolTab(
                      id: 'tab',
                      icon: Icons.tune_rounded,
                      label: '工具',
                      tooltip: '工具',
                    ),
                  ],
                  selectedId: 'tab',
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is ArtworkCardSurface && widget.id == 'card',
      ),
      findsOneWidget,
    );
    expect(find.byType(LayeredArtworkStack), findsOneWidget);
    expect(find.byType(PosterRail), findsOneWidget);
    expect(find.byType(ExpandableToolTabs), findsOneWidget);
  });
}

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/ui/sidebar/sidebar.dart';

void main() {
  testWidgets('Sidebar mounts Draggable and DragTarget for pages', (tester) async {
    final now = DateTime.now();
    final pages = [
      Page(
        id: 'p1',
        title: 'Parent Folder',
        parentId: null,
        icon: '📁',
        cover: null,
        orderKey: 'a0',
        createdAt: now,
        trashedAt: null,
      ),
      Page(
        id: 'p2',
        title: 'Child Page',
        parentId: 'p1',
        icon: null,
        cover: null,
        orderKey: 'a1',
        createdAt: now,
        trashedAt: null,
      ),
    ];

    String? movedPageId;
    String? newParentId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Sidebar(
            pages: pages,
            selectedPageId: 'p2',
            onSelectPage: (_) {},
            onNewRootPage: () {},
            onNewSubpage: (_) {},
            onTrashPage: (_) {},
            onOpenSearch: () {},
            onMovePage: (pageId, {targetParentId, prevOrderKey, nextOrderKey}) {
              movedPageId = pageId;
              newParentId = targetParentId;
            },
            onToggleTrash: () {},
          ),
        ),
      ),
    );

    // Verify Draggable widgets exist for pages
    expect(find.byType(Draggable<String>), findsNWidgets(2));
    // Verify DragTarget exists
    expect(find.byType(DragTarget<String>), findsWidgets);

    // Drag Child Page onto Root drop target
    final rootTarget = find.byType(DragTarget<String>).last;
    final childDraggable = find.text('Child Page');

    // Simulate drag gesture
    final gesture = await tester.startGesture(tester.getCenter(childDraggable));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(rootTarget));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedPageId, 'p2');
    expect(newParentId, isNull);
  });
}

import 'package:delta/ui/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Стартовый экран и переход в настройки', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeltaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Delta · Главная'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Delta · Настройки'), findsOneWidget);
  });
}

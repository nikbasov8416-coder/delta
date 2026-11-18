import 'package:delta/ui/app.dart';
import 'package:delta/ui/navigation/app_router.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/theme_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';
import '../widget_test.dart' show TestPin;

void main() {
  testWidgets('Оформление меняется сразу и переживает перезапуск до входа', (
    tester,
  ) async {
    final repo = await testRepository();
    addTearDown(repo.close);
    final secrets = MemorySecrets();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    Widget application(int generation) => ProviderScope(
      key: ValueKey(generation),
      overrides: [
        repositoryProvider.overrideWith((ref) async => repo),
        pinServiceProvider.overrideWithValue(TestPin()),
        secretStoreProvider.overrideWithValue(secrets),
      ],
      child: const DeltaApp(),
    );
    ThemeMode? mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
    Brightness brightness(Finder finder) =>
        Theme.of(tester.element(finder)).brightness;

    await tester.pumpWidget(application(1));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.system);
    expect(brightness(find.text('Вход в Delta')), Brightness.light);
    await tester.enterText(find.byType(TextField).first, '135790');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeltaApp)),
    );
    final outbox = await repo.query('SELECT * FROM sync_outbox ORDER BY seq');
    container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Оформление'), findsOneWidget);
    final field = find.byType(DropdownButton<ThemeMode>);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная').last);
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect(brightness(find.text('Оформление')), Brightness.dark);
    expect(secrets.values[ThemeSettingsController.storageKey], 'dark');
    expect(
      (await repo.query('SELECT * FROM sync_outbox ORDER BY seq'))
          .map((row) => row.values),
      outbox.map((row) => row.values),
    );

    await tester.pumpWidget(application(2));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect(brightness(find.text('Вход в Delta')), Brightness.dark);

    secrets.values[ThemeSettingsController.storageKey] = 'unknown';
    await tester.pumpWidget(application(3));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.system);
    expect(brightness(find.text('Вход в Delta')), Brightness.light);
  });
}

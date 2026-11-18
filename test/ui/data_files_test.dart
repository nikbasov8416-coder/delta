import 'package:delta/ui/providers.dart';
import 'package:delta/ui/screens/data_files.dart';
import 'package:delta/ui/sync/sync_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../sync/fake_disk.dart';
import '../sync/sync_test.dart' show TestDevice;

void main() {
  testWidgets('Копия предупреждает об отдельном пароле и проверяет повтор', (
    tester,
  ) async {
    final device = await TestDevice.open(FakeDisk(), 1);
    addTearDown(device.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWith((ref) async => device.sync),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DataFilesView(export: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Если его потерять'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Выдуманный пароль');
    await tester.enterText(
      find.byType(TextField).last,
      'Другой выдуманный пароль',
    );
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Пароли не совпадают.'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Резервная копия сохранена.'), findsNothing);
  });

  testWidgets(
    'Подключённая синхронизация блокирует восстановление и предлагает отправить очередь',
    (tester) async {
      final device = await TestDevice.open(FakeDisk(), 1);
      addTearDown(device.close);
      await device.setup(create: true);
      expect(device.sync.error, isNull);
      await device.repo.saveLiquidity(
        name: 'Пробный уровень',
        order: 9,
        color: 4280723098,
      );
      await device.sync.refreshPending();
      Widget screen(Widget child) => ProviderScope(
        overrides: [
          syncServiceProvider.overrideWith((ref) async => device.sync),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pumpWidget(screen(const DataFilesView(export: false)));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Чтобы восстановить из файла, сначала отключите синхронизацию на этом устройстве',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, 'Настройки синхронизации'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Восстановить из файла'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(screen(const SyncSettings()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отключить синхронизацию на этом устройстве'));
      await tester.pumpAndSettle();
      expect(find.text('Сначала синхронизировать'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Всё равно отключить'),
      );
      final colors = Theme.of(tester.element(find.byType(AlertDialog)))
          .colorScheme;
      expect(confirm.style!.backgroundColor!.resolve({}), colors.error);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(device.sync.enabled, isTrue);
    },
  );
}

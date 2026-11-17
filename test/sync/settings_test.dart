import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/sync/sync_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';
import 'fake_disk.dart';

void main() {
  testWidgets(
    'Подключение: предупреждение, замена по умолчанию, явное подтверждение',
    (tester) async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final overview = await repo.overview();
      await repo.saveStorage(
        name: 'Выдуманное',
        type: 'cash',
        liquidityId: overview.liquidity.first.id,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [overview.currencies.first.id],
      );
      final service = SyncService(
        repo,
        MemorySecrets(),
        diskFactory: (_, _) => FakeDisk(),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncServiceProvider.overrideWith((ref) async => service)],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: SyncSettings())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(syncLossWarning), findsOneWidget);
      await tester.tap(find.text('Подключиться'));
      await tester.pumpAndSettle();
      expect(find.text('Заменить данными с Диска'), findsOneWidget);
      expect(
        find.textContaining('Замена удалит локальные финансовые данные'),
        findsOneWidget,
      );
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Подключиться'),
      );
      expect(confirm.onPressed, isNull);
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(
        (await repo.overview()).storages.single.text('name'),
        'Выдуманное',
      );
    },
  );
  testWidgets('Чистое устройство: нет предупреждения и выбора замены', (
    tester,
  ) async {
    final repo = await testRepository();
    addTearDown(repo.close);
    final service = SyncService(
      repo,
      MemorySecrets(),
      diskFactory: (_, _) => FakeDisk(),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncServiceProvider.overrideWith((ref) async => service)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SyncSettings())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подключиться'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Замена удалит локальные финансовые данные'),
      findsNothing,
    );
    expect(find.byType(DropdownButtonFormField<bool>), findsNothing);
    expect(find.text(syncLossWarning), findsWidgets);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });
}

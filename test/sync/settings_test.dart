import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/sync/sync_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:delta/ui/sync/yandex_oauth.dart';

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
        diskFactory: (_) => FakeDisk(),
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
      diskFactory: (_) => FakeDisk(),
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
  testWidgets(
    'OAuth: только скрытый токен и безопасная ссылка для входа без client secret',
    (tester) async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final service = SyncService(
        repo,
        MemorySecrets(),
        diskFactory: (_) => FakeDisk(),
      );
      addTearDown(service.dispose);
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
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
      expect(find.text('Логин Яндекса'), findsNothing);
      expect(find.text('Пароль приложения Яндекса'), findsNothing);
      final token = find.widgetWithText(TextField, 'OAuth-токен Яндекса');
      expect(tester.widget<TextField>(token).obscureText, isTrue);
      await tester.enterText(token, 'synthetic-token');
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Войти через Яндекс'),
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Войти через Яндекс'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.tap(find.text('Скопировать ссылку'));
      await tester.pumpAndSettle();
      expect(copied, yandexAuthorizationUri.toString());
      final uri = Uri.parse(copied!);
      expect(uri.scheme, 'https');
      expect(uri.host, 'oauth.yandex.ru');
      expect(uri.queryParameters, {
        'response_type': 'token',
        'client_id': '9dfd06f99533434999c25fc578b45663',
        'force_confirm': 'yes',
      });
      expect(copied, isNot(contains('synthetic-token')));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
    },
  );
}

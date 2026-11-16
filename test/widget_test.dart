import 'package:delta/ui/app.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/domain/security/pin_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_database.dart';

class TestPin extends PinService {
  TestPin() : super(read: (_) => Future.value(null), write: (_, _) async {});
  @override
  Future<bool> get configured async => true;
  @override
  Future<Duration> delay() async => Duration.zero;
  @override
  Future<bool> verify(String pin) async => pin == '135790';
}

void main() {
  testWidgets('До входа база не открывается; после PIN доступны экраны', (
    tester,
  ) async {
    final repo = await testRepository();
    addTearDown(repo.close);
    var accessed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secretStoreProvider.overrideWithValue(MemorySecrets()),
          pinServiceProvider.overrideWithValue(TestPin()),
          repositoryProvider.overrideWith((ref) async {
            accessed = true;
            return repo;
          }),
        ],
        child: const DeltaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вход в Delta'), findsOneWidget);
    expect(accessed, isFalse);
    await tester.enterText(find.byType(TextField).first, '135790');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(accessed, isTrue);
    expect(find.text('Delta · Главная'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Места хранения'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить место хранения'), findsOneWidget);
    // В фоне суммы скрыты сразу, даже до истечения таймаута блокировки.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Добавить место хранения'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Добавить место хранения'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Вход в Delta'), findsOneWidget);
  });
  testWidgets('Ввод слепка с запятой, фиксация и показ итогов', (tester) async {
    final repo = await testRepository();
    addTearDown(repo.close);
    final initial = await repo.overview();
    await repo.saveStorage(
      name: 'Выдуманное место',
      type: 'cash',
      liquidityId: initial.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [
        initial.currencies.firstWhere((c) => c.text('code') == 'RUB').id,
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secretStoreProvider.overrideWithValue(MemorySecrets()),
          pinServiceProvider.overrideWithValue(TestPin()),
          repositoryProvider.overrideWith((ref) async => repo),
        ],
        child: const DeltaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '135790');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новый слепок'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Заполнено 0 из 1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '1 234,56');
    await tester.enterText(find.byType(TextField).at(1), '234,56');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Заполнено 1 из 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Зафиксировать слепок'), 200);
    await tester.tap(find.text('Зафиксировать слепок'));
    await tester.pumpAndSettle();
    expect((await repo.overview()).snapshots.single.text('status'), 'fixed');
    await tester.scrollUntilVisible(
      find.textContaining('Всего: 1 234,56 ₽'),
      200,
    );
    expect(find.textContaining('личные 1 000,00 ₽'), findsWidgets);
  });
}

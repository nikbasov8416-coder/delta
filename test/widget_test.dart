import 'package:decimal/decimal.dart';
import 'package:delta/domain/rates/rates.dart';
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

class WidgetRateGateway implements RateGateway {
  @override
  Future<RateBatch> fetch(Set<String> codes, DateTime date) async => RateBatch(
    quotes: {
      for (final code in codes)
        code: RateQuote(
          code: code,
          date: dayKey(date),
          value: Decimal.parse(dayKey(date) == '2026-01-10' ? '2' : '3'),
          source: 'cbr',
          effectiveAt: dayKey(date),
          fetchedAt: DateTime.utc(2026, 1, 12, 10),
        ),
    },
  );
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
  testWidgets('Кнопки подтверждения: без изменений и общий вопрос с отменой', (
    tester,
  ) async {
    final repo = await testRepository();
    addTearDown(repo.close);
    final data = await repo.overview();
    final rub = data.currencies.firstWhere((c) => c.text('code') == 'RUB').id;
    final usd = data.currencies.firstWhere((c) => c.text('code') == 'USD').id;
    await repo.saveStorage(
      name: 'Выдуманное место',
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [rub, usd],
    );
    final original = await repo.createSnapshot('2026-01-10', '');
    for (final row in (await repo.snapshot(original)).lines) {
      await repo.saveLine(row.id, '5', '1', '');
    }
    await repo.saveRate(original, usd, '2');
    await repo.finalizeSnapshot(original);
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
    final id = (await repo.overview()).snapshots.first.id;
    expect(
      (await repo.snapshot(id)).lines.every((l) => !l.flag('confirmed')),
      isTrue,
    );
    await tester.ensureVisible(find.text('✓ без изменений').first);
    await tester.tap(find.text('✓ без изменений').first);
    await tester.pumpAndSettle();
    expect(
      (await repo.snapshot(id)).lines.where((l) => l.flag('confirmed')).length,
      1,
    );
    await tester.scrollUntilVisible(
      find.text('Подтвердить все непроверенные'),
      -200,
    );
    await tester.tap(find.text('Подтвердить все непроверенные'));
    await tester.pumpAndSettle();
    expect(find.text('Точно подтвердить все непроверенные?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(
      (await repo.snapshot(id)).lines.where((l) => l.flag('confirmed')).length,
      1,
    );
    await tester.tap(find.text('Подтвердить все непроверенные'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, подтвердить'));
    await tester.pumpAndSettle();
    expect(
      (await repo.snapshot(id)).lines
          .every((l) => l.flag('confirmed') && l.text('amount') == '5'),
      isTrue,
    );
  });
  testWidgets('Переключатель итогов меняет оценку, но не курсы слепка', (
    tester,
  ) async {
    final repo = await testRepository(
      gateway: WidgetRateGateway(),
      now: () => DateTime.utc(2026, 1, 12, 10),
    );
    addTearDown(repo.close);
    final data = await repo.overview();
    await repo.saveStorage(
      name: 'Выдуманное место',
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: data.currencies
          .where((c) => ['RUB', 'USD'].contains(c.text('code')))
          .map((c) => c.id)
          .toList(),
    );
    final id = await repo.createSnapshot('2026-01-10', '');
    for (final row in (await repo.snapshot(id)).lines) {
      await repo.saveLine(row.id, '10', '2', '');
    }
    await repo.finalizeSnapshot(id);
    final before = (await repo.snapshot(id)).rates
        .map((r) => r.values)
        .toList();
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
    expect(find.text('По валютам'), findsNothing);
    expect(find.textContaining('Действует / наблюдение:'), findsNothing);
    expect(find.text('По местам хранения'), findsOneWidget);
    expect(find.text('По ликвидности'), findsOneWidget);
    expect(find.textContaining('Всего: 30,00 ₽'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('По сегодняшнему'), 200);
    await tester.tap(find.text('По сегодняшнему'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Всего: 40,00 ₽'), findsOneWidget);
    expect(
      (await repo.snapshot(id)).rates.map((r) => r.values).toList(),
      before,
    );
    expect((await repo.snapshot(id)).audit, isEmpty);
    await tester.ensureVisible(find.text('По курсу слепка'));
    await tester.tap(find.text('По курсу слепка'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Всего: 30,00 ₽'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Открыть слепок'), 200);
    await tester.tap(find.text('Открыть слепок'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('По валютам'), 300);
    expect(find.text('По валютам'), findsOneWidget);
    expect(find.textContaining('Действует / наблюдение:'), findsWidgets);
  });
}

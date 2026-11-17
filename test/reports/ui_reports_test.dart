import 'package:delta/ui/app.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/money_visibility.dart';
import 'package:delta/ui/navigation/app_router.dart';
import 'package:delta/ui/reports/report_chart.dart';
import 'package:delta/ui/reports/reports_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';
import '../widget_test.dart' show TestPin;
import 'reports_test.dart' show snapshot, position;

void main() {
  testWidgets(
    'Период меняет точки; суммы/подсказки скрываются и состояние хранится локально',
    (tester) async {
      final now = DateTime.now();
      String day(DateTime d) => d.toIso8601String().substring(0, 10);
      final data = [
        snapshot('a', day(DateTime.utc(now.year - 2, now.month, now.day)), [
          position('a', 'RUB', '12345'),
        ], {}),
        snapshot('b', day(DateTime.utc(now.year, now.month - 9, now.day)), [
          position('a', 'RUB', '56789'),
        ], {}),
        snapshot('c', day(DateTime.utc(now.year, now.month, now.day)), [
          position('a', 'RUB', '90000'),
        ], {}),
      ];
      final secrets = MemorySecrets();
      Widget app(int key) => ProviderScope(
        key: ValueKey(key),
        overrides: [
          secretStoreProvider.overrideWithValue(secrets),
          reportSnapshotsProvider.overrideWith((ref) async => data),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [AmountsEye()]),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ReportsView(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNWidgets(4));
      LineChart chart() =>
          tester.widget<LineChart>(find.byType(LineChart).first);
      expect(chart().data.lineBarsData.first.spots, hasLength(3));
      await tester.tap(find.text('Год'));
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.first.spots, hasLength(2));
      await tester.tap(find.text('Полгода'));
      await tester.pumpAndSettle();
      expect(chart().data.lineBarsData.first.spots, hasLength(1));
      final line = chart().data.lineBarsData.first;
      final tooltip = chart().data.lineTouchData.touchTooltipData
          .getTooltipItems([LineBarSpot(line, 0, line.spots.last)]);
      expect(tooltip.single!.text, contains('90 000 ₽'));
      await tester.tap(find.byTooltip('Скрыть суммы'));
      await tester.pumpAndSettle();
      expect(chart().data.lineTouchData.enabled, isFalse);
      expect(chart().data.titlesData.leftTitles.sideTitles.showTitles, isFalse);
      expect(find.textContaining('Общая разница: •••'), findsOneWidget);
      expect(find.textContaining('90 000'), findsNothing);
      expect(secrets.values['hide_amounts'], 'true');
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      expect(chart().data.lineTouchData.enabled, isFalse);
      expect(find.byTooltip('Показать суммы'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Глаз на главной/слепке, аудит и редактор не раскрывают скрытые суммы; мини-график открывает отчёты',
    (tester) async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final data = await repo.overview();
      await repo.saveStorage(
        name: 'Выдуманное место',
        type: 'cash',
        liquidityId: data.liquidity.first.id,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [
          data.currencies.firstWhere((c) => c.text('code') == 'RUB').id,
        ],
      );
      final id = await repo.createSnapshot('2026-01-10', '');
      final line = (await repo.snapshot(id)).lines.single;
      await repo.saveLine(line.id, '10', '2', '');
      await repo.finalizeSnapshot(id);
      await repo.saveLine(line.id, '20', '3', '');
      final secrets = MemorySecrets()..values['hide_amounts'] = 'true';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secretStoreProvider.overrideWithValue(secrets),
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
      expect(find.byType(ReportPlot), findsOneWidget);
      expect(find.textContaining('20,00'), findsNothing);
      await tester.ensureVisible(find.text('Открыть отчёты'));
      await tester.tap(find.text('Открыть отчёты'));
      await tester.pumpAndSettle();
      expect(find.text('Delta · Отчёты'), findsOneWidget);
      expect(find.textContaining('Графики и сравнение — этап 5'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeltaApp)),
      );
      container.read(appRouterProvider).go('/snapshots/$id');
      await tester.pumpAndSettle();
      expect(find.textContaining('20,00'), findsNothing);
      await tester.scrollUntilVisible(find.byType(ExpansionTile), 400);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Всего: ••• → •••'), findsOneWidget);
      expect(find.textContaining('10 → 20'), findsNothing);
      final lineTile = find.widgetWithText(ListTile, 'RUB: •••');
      await tester.scrollUntilVisible(
        lineTile,
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(lineTile);
      await tester.pumpAndSettle();
      final inputs = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(inputs, hasLength(3));
      expect(inputs.take(2).every((f) => f.obscureText), isTrue);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Показать суммы'));
      await tester.pumpAndSettle();
      expect(find.textContaining('20,00'), findsWidgets);
      expect(secrets.values['hide_amounts'], 'false');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

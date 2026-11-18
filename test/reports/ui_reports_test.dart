import 'package:delta/domain/reports/reports.dart';
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
    'Три слепка: сбитая дата или отсутствующий курс исключают только средний',
    (tester) async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final overview = await repo.overview();
      final usd = overview.currencies
          .firstWhere((c) => c.text('code') == 'USD')
          .id;
      await repo.saveStorage(
        name: 'Выдуманный счёт',
        type: 'cash',
        liquidityId: overview.liquidity.first.id,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [usd],
      );
      final ids = <String>[];
      for (var month = 1; month <= 3; month++) {
        final id = await repo.createSnapshot('2026-0$month-10', '');
        final line = (await repo.snapshot(id)).lines.single;
        await repo.saveLine(line.id, '${month * 10}', '0', '');
        await repo.saveRate(id, usd, '90');
        await repo.finalizeSnapshot(id);
        ids.add(id);
      }
      await repo.db.customStatement(
        "UPDATE snapshot_rate SET rate_date='2026-02-09' WHERE snapshot_id=?",
        [ids[1]],
      );
      Future<void> checkReports() async {
        final result = await repo.reportSnapshots();
        expect(result.snapshots.map((s) => s.id), [ids.first, ids.last]);
        expect(result.excludedDates, ['2026-02-10']);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              secretStoreProvider.overrideWithValue(MemorySecrets()),
              reportSnapshotsProvider.overrideWith((ref) async => result),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SingleChildScrollView(child: ReportsView())),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Слепок от 10.02.2026 не учтён: обновите его курсы'),
          findsOneWidget,
        );
        final charts = tester.widgetList<LineChart>(find.byType(LineChart));
        expect(charts, hasLength(4));
        for (final chart in charts) {
          expect(chart.data.lineBarsData.first.spots, hasLength(2));
        }
        final selectors = tester.widgetList<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        expect(selectors, hasLength(2));
        for (final selector in selectors) {
          expect(selector.items!.map((item) => item.value), [
            ids.first,
            ids.last,
          ]);
        }
      }

      await checkReports();
      // Тот же пользовательский результат при отсутствующем курсе.
      await repo.db.customStatement(
        'DELETE FROM snapshot_rate WHERE snapshot_id=?',
        [ids[1]],
      );
      await checkReports();
      // Даже если пригодных слепков нет, причины исключения остаются на экране.
      await repo.db.customStatement('DELETE FROM snapshot_rate');
      final empty = await repo.reportSnapshots();
      expect(empty.snapshots, isEmpty);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            reportSnapshotsProvider.overrideWith((ref) async => empty),
          ],
          child: const MaterialApp(home: Scaffold(body: ReportsView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('не учтён: обновите его курсы'),
        findsNWidgets(3),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
          reportSnapshotsProvider.overrideWith((ref) async => ReportData(data)),
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
      expect(tooltip.single!.text, contains('90\u00a0000,00 ₽'));
      await tester.tap(find.byTooltip('Скрыть суммы'));
      await tester.pumpAndSettle();
      final hiddenLine = chart().data.lineBarsData.first;
      expect(
        chart().data.lineTouchData.touchTooltipData
            .getTooltipItems([
              LineBarSpot(hiddenLine, 0, hiddenLine.spots.last),
            ])
            .single!
            .text,
        endsWith('· •••'),
      );
      expect(chart().data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
      expect(find.text('•••'), findsWidgets);
      expect(find.textContaining('Общая разница: •••'), findsOneWidget);
      expect(find.textContaining('90\u00a0000'), findsNothing);
      expect(secrets.values['hide_amounts'], 'true');
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      expect(find.text('•••'), findsWidgets);
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
      final plotLink = find.byKey(const ValueKey('home-report-link'));
      await tester.ensureVisible(plotLink);
      await tester.tap(plotLink);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Отчёты'), findsOneWidget);
      expect(find.textContaining('Графики и сравнение — этап 5'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeltaApp)),
      );
      container.read(appRouterProvider).go('/snapshots/$id');
      await tester.pumpAndSettle();
      expect(find.textContaining('20,00'), findsNothing);
      final audit = find.widgetWithText(
        ExpansionTile,
        'Сумма / семейная часть / заметка',
      );
      await tester.scrollUntilVisible(audit, 220);
      await Scrollable.ensureVisible(tester.element(audit), alignment: .45);
      await tester.pumpAndSettle();
      await tester.tap(audit);
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

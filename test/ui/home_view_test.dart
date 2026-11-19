import 'package:decimal/decimal.dart';
import 'package:delta/domain/finance/records.dart';
import 'package:delta/domain/reports/reports.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/screens/home_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';

void main() {
  for (final (description, cashAmount) in [
    ('по убыванию суммы в рублях', 150),
    ('по названию при равной сумме', 200),
  ]) {
    testWidgets('Главная показывает места хранения $description', (
      tester,
    ) async {
      final snapshot = ReportSnapshot(
        id: 'snapshot',
        date: '2026-01-10',
        rates: {'USD': Decimal.fromInt(100)},
        positions: [
          for (final (name, currency, amount) in [
            ('Архив', 'RUB', 20),
            ('Касса', 'RUB', cashAmount),
            ('Банк', 'USD', 2),
          ])
            ReportPosition(
              storageId: name,
              storageName: name,
              currency: currency,
              precision: 2,
              liquidityId: 'cash',
              liquidityName: 'Доступно',
              amount: Decimal.fromInt(amount),
              family: Decimal.zero,
            ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secretStoreProvider.overrideWithValue(MemorySecrets()),
            reportSnapshotsProvider.overrideWith(
              (ref) async => ReportData([snapshot]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeView(
                  overview: const FinanceOverview(
                    currencies: [],
                    liquidity: [],
                    storages: [],
                    storageCurrencies: [],
                    snapshots: [],
                  ),
                  onNewSnapshot: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('По местам хранения'), findsOneWidget);
      final bank = find.widgetWithText(ExpansionTile, 'Банк');
      final cash = find.widgetWithText(ExpansionTile, 'Касса');
      final archive = find.widgetWithText(ExpansionTile, 'Архив');
      expect(tester.getTopLeft(bank).dy, lessThan(tester.getTopLeft(cash).dy));
      expect(
        tester.getTopLeft(cash).dy,
        lessThan(tester.getTopLeft(archive).dy),
      );
    });
  }
}

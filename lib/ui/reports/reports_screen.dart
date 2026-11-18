import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/reports/reports.dart';
import '../providers.dart';
import '../messages.dart';
import '../finance_format.dart';
import '../money_visibility.dart';
import 'report_chart.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});
  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  ReportPeriod period = ReportPeriod.all;
  String? firstId, secondId;
  @override
  Widget build(BuildContext context) => ref
      .watch(reportSnapshotsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const AppMessage(
          'Не удалось построить отчёт. Проверьте заполнение курсов зафиксированных слепков.',
        ),
        data: (result) {
          final all = result.snapshots;
          final warnings = [
            for (final date in result.excludedDates)
              AppMessage(
                'Слепок от ${displayDate(date)} не учтён: обновите его курсы',
                kind: MessageKind.warning,
              ),
          ];
          if (all.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...warnings,
                const Text(
                  'Пока нет зафиксированных слепков с актуальными курсами.',
                ),
              ],
            );
          }
          final filtered = reportPeriod(all, period, DateTime.now());
          final first =
              all.where((s) => s.id == firstId).firstOrNull ??
              all[all.length > 1 ? all.length - 2 : 0];
          final second =
              all.where((s) => s.id == secondId).firstOrNull ?? all.last;
          final comparison = compareSnapshots(first, second);
          final precision = {
            for (final position in [...first.positions, ...second.positions])
              position.currency: currencyDisplayPrecision(
                position.kind,
                position.precision,
              ),
          };
          String amount(Decimal value, [String? code]) =>
              visibleMoney(ref, value, precision: precision[code] ?? 2);
          Widget group(
            String heading,
            Map<String, ComparisonAmount> values,
            Map<String, String> names,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: Theme.of(context).textTheme.titleMedium),
              for (final e in values.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(names[e.key] ?? e.key),
                      Text(
                        '${amount(e.value.before)} ₽ → ${amount(e.value.after)} ₽; разница ${amount(e.value.delta)} ₽',
                      ),
                      for (final code in e.value.nativeDelta.keys)
                        Text(
                          '$code: ${amount(e.value.nativeBefore[code] ?? Decimal.zero, code)} → ${amount(e.value.nativeAfter[code] ?? Decimal.zero, code)}; разница ${amount(e.value.nativeDelta[code]!, code)}',
                        ),
                    ],
                  ),
                ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...warnings,
              SegmentedButton<ReportPeriod>(
                segments: const [
                  ButtonSegment(
                    value: ReportPeriod.all,
                    label: Text('Всё время'),
                  ),
                  ButtonSegment(value: ReportPeriod.year, label: Text('Год')),
                  ButtonSegment(
                    value: ReportPeriod.halfYear,
                    label: Text('Полгода'),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (v) => setState(() => period = v.single),
              ),
              const SizedBox(height: 16),
              for (final entry in const {
                ReportChart.total: 'Общий итог в ₽',
                ReportChart.liquidity: 'По ликвидности с накоплением',
                ReportChart.currency: 'По валютам в ₽',
                ReportChart.family: 'Личные и семейные',
              }.entries) ...[
                Text(
                  entry.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ReportPlot(snapshots: filtered, chart: entry.key),
                if (entry.key == ReportChart.liquidity)
                  const Text(
                    'Ликвидность — по текущему уровню места хранения, включая старые слепки.',
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 20),
              ],
              const Divider(),
              Text(
                'Сравнение слепков',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Период выше относится к графикам. Для сравнения доступны зафиксированные слепки с актуальными курсами.',
              ),
              if (all.length < 2)
                const Text('Для сравнения нужны два зафиксированных слепка.')
              else ...[
                for (final isFirst in [true, false])
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${isFirst}_${isFirst ? first.id : second.id}',
                    ),
                    initialValue: isFirst ? first.id : second.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFirst ? 'Первый слепок' : 'Второй слепок',
                    ),
                    items: [
                      for (var i = 0; i < all.length; i++)
                        DropdownMenuItem(
                          value: all[i].id,
                          child: Text(
                            '${displayDate(all[i].date)} · слепок ${i + 1}',
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      if (isFirst) {
                        firstId = id;
                      } else {
                        secondId = id;
                      }
                    }),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${displayDate(first.date)} → ${displayDate(second.date)}',
                ),
                Text('Общая разница: ${amount(comparison.total.delta)} ₽'),
                Text(
                  'Изменение остатков: ${amount(comparison.total.balance)} ₽',
                ),
                Text('Курсовая разница: ${amount(comparison.total.fx)} ₽'),
                const Text(
                  'Если валюта есть только в одном слепке и второго курса нет, используем имеющийся курс для обеих сторон: появление/исчезновение — изменение остатков.',
                  style: TextStyle(fontSize: 12),
                ),
                group(
                  'По местам хранения',
                  comparison.byStorage,
                  comparison.storageNames,
                ),
                group('По валютам', comparison.byCurrency, {}),
                group(
                  'По ликвидности',
                  comparison.byLiquidity,
                  comparison.liquidityNames,
                ),
              ],
            ],
          );
        },
      );
}

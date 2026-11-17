import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/reports/reports.dart';
import '../money_visibility.dart';

class ReportPlot extends ConsumerWidget {
  const ReportPlot({
    required this.snapshots,
    required this.chart,
    this.mini = false,
    super.key,
  });
  final List<ReportSnapshot> snapshots;
  final ReportChart chart;
  final bool mini;
  static const palette = [
    Colors.teal,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.green,
    Colors.pink,
    Colors.indigo,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = amountsHidden(ref), series = reportSeries(snapshots, chart);
    if (snapshots.isEmpty || series.isEmpty) {
      return const Text('Нет зафиксированных слепков за период.');
    }
    final spots = [
      for (final s in series)
        [
          for (var i = 0; i < s.values.length; i++)
            FlSpot(i.toDouble(), s.values[i].toDouble()),
        ],
    ];
    if (spots.expand((x) => x).any((p) => !p.y.isFinite)) {
      return const Text('Значения слишком велики для отрисовки графика.');
    }
    Color color(int i) => series[i].color == null
        ? palette[i % palette.length]
        : Color(series[i].color!);
    final lines = [
      for (var i = 0; i < series.length; i++)
        LineChartBarData(
          spots: spots[i],
          color: color(i),
          barWidth: mini ? 2 : 3,
          isCurved: false,
          dotData: FlDotData(
            show: snapshots.length == 1 || !mini && snapshots.length < 25,
          ),
          belowBarData: BarAreaData(
            show: chart == ReportChart.liquidity && i == 0,
            color: color(i).withValues(alpha: 0.24),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: mini ? 110 : 250,
          child: ExcludeSemantics(
            excluding: hidden,
            child: LineChart(
              LineChartData(
                lineBarsData: lines,
                betweenBarsData: chart == ReportChart.liquidity
                    ? [
                        for (var i = 1; i < lines.length; i++)
                          BetweenBarsData(
                            fromIndex: i - 1,
                            toIndex: i,
                            color: color(i).withValues(alpha: 0.24),
                          ),
                      ]
                    : [],
                minX: 0,
                maxX: snapshots.length == 1
                    ? 1
                    : (snapshots.length - 1).toDouble(),
                minY: 0,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: !mini),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: !hidden && !mini,
                      reservedSize: 90,
                      getTitlesWidget: (v, meta) => Text(
                        '${formatMoney(Decimal.parse(v.toString()), precision: 0)} ₽',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: !mini,
                      interval: snapshots.length > 6
                          ? (snapshots.length / 4).ceilToDouble()
                          : 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 ||
                            i >= snapshots.length ||
                            v != i.toDouble()) {
                          return const SizedBox.shrink();
                        }
                        final day = snapshots[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${day.substring(8)}.${day.substring(5, 7)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: !hidden && !mini,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touched) => [
                      for (final point in touched)
                        hidden
                            ? null
                            : LineTooltipItem(
                                '${snapshots[point.spotIndex].date}\n${series[point.barIndex].name}: ${formatMoney(series[point.barIndex].values[point.spotIndex], precision: 0)} ₽',
                                const TextStyle(color: Colors.white),
                              ),
                    ],
                  ),
                ),
              ),
              duration: Duration.zero,
            ),
          ),
        ),
        if (!mini)
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < series.length; i++)
                Text(series[i].name, style: TextStyle(color: color(i))),
            ],
          ),
      ],
    );
  }
}

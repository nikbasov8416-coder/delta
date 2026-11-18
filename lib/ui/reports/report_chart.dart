import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/reports/reports.dart';
import '../delta_theme.dart';
import '../finance_format.dart';
import '../messages.dart';
import '../money_visibility.dart';

class ReportDates {
  ReportDates(List<ReportSnapshot> snapshots) {
    if (snapshots.isEmpty) return;
    final start = DateTime.parse('${snapshots.first.date}T00:00:00Z');
    final days = <String, int>{};
    for (final snapshot in snapshots) {
      days.update(snapshot.date, (count) => count + 1, ifAbsent: () => 1);
    }
    final seen = <String, int>{};
    for (final snapshot in snapshots) {
      final day = snapshot.date;
      final count = days[day]!;
      final index = seen.update(day, (value) => value + 1, ifAbsent: () => 0);
      final offset = DateTime.parse('${day}T00:00:00Z')
          .difference(start)
          .inDays;
      final x = offset + index / count;
      final label =
          '${displayDate(day, short: true)}${count > 1 ? ' ($count)' : ''}';
      positions.add(x);
      labels.add(label);
      ticks.putIfAbsent(x.floorToDouble(), () => label);
    }
  }

  final positions = <double>[];
  final labels = <String>[];
  final ticks = <double, String>{};

  Map<double, String> sparseTicks(int limit) {
    final keys = ticks.keys.toList();
    if (keys.length <= limit) return ticks;
    return {
      for (var i = 0; i < limit; i++)
        keys[(i * (keys.length - 1) / (limit - 1)).round()]:
            ticks[keys[(i * (keys.length - 1) / (limit - 1)).round()]]!,
    };
  }
}

String compactRubles(double value) {
  final amount = Decimal.parse(value.toStringAsFixed(2));
  if (value.abs() < 1000) return formatMoney(amount, precision: 0);
  final (unit, label) = value.abs() >= 1000000
      ? (1000000, 'млн')
      : (1000, 'тыс');
  final scaled = (amount / Decimal.fromInt(unit)).toDecimal();
  return '${formatDecimal(scaled, precision: 1, trimZeros: true)} $label';
}

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
    personalColor,
    Colors.blue,
    Colors.deepOrange,
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
    final dates = ReportDates(snapshots);
    final spots = [
      for (final s in series)
        [
          for (var i = 0; i < s.values.length; i++)
            FlSpot(dates.positions[i], s.values[i].toDouble()),
        ],
    ];
    final values = spots.expand((x) => x).map((spot) => spot.y);
    if (values.any((value) => !value.isFinite)) {
      return const AppMessage('Значения слишком велики для отрисовки графика.');
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color color(int i) => switch (chart) {
      ReportChart.family =>
        series[i].name == 'Семейные' ? familyColor : personalColor,
      ReportChart.total => colorScheme.primary,
      _ =>
        series[i].color == null
            ? palette[i % palette.length]
            : Color(series[i].color!),
    };
    final lines = [
      for (var i = 0; i < series.length; i++)
        LineChartBarData(
          spots: spots[i],
          color: color(i),
          barWidth: mini ? 2.5 : 3,
          dotData: FlDotData(
            show: mini || snapshots.length < 25,
            checkToShowDot: (spot, _) => !mini || spot == spots[i].last,
          ),
          belowBarData: BarAreaData(
            show: mini || chart == ReportChart.liquidity && i == 0,
            color: mini ? null : color(i).withValues(alpha: 0.24),
            gradient: mini
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color(i).withValues(alpha: 0.30),
                      color(i).withValues(alpha: 0.02),
                    ],
                  )
                : null,
          ),
        ),
    ];
    final high = values.reduce(math.max);
    final low = mini ? values.reduce(math.min) : 0.0;
    final range = high - low;
    final verticalStep = (high == 0 ? 1.0 : high) / 4;
    final axisEnd = math.max(dates.positions.last, 1.0);
    final axisWidth = hidden ? 24.0 : 52.0;
    final axisText = theme.textTheme.labelSmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        final ticks = dates.sparseTicks(constraints.maxWidth < 450 ? 3 : 6);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(mini ? 5 : 0, mini ? 0 : 14, 12, 0),
              child: SizedBox(
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
                      maxX: axisEnd,
                      minY: mini ? math.max(0, low - range * 0.1) : 0,
                      maxY: mini
                          ? high +
                                (range == 0
                                    ? math.max(high * 0.1, 1)
                                    : range * 0.1)
                          : verticalStep * 4,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: !mini,
                        horizontalInterval: verticalStep,
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: !mini,
                            reservedSize: axisWidth,
                            interval: verticalStep,
                            getTitlesWidget: (value, _) => Text(
                              hidden ? '•••' : compactRubles(value),
                              style: axisText,
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(),
                      ),
                      extraLinesData: ExtraLinesData(
                        extraLinesOnTop: false,
                        verticalLines: [
                          if (!mini)
                            for (final x in ticks.keys)
                              VerticalLine(
                                x: x,
                                color: colorScheme.outlineVariant,
                                strokeWidth: 1,
                              ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        enabled: !mini,
                        touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => colorScheme.inverseSurface,
                          getTooltipItems: (touched) => [
                            for (final point in touched)
                              LineTooltipItem(
                                '${dates.labels[point.spotIndex]} · ${hidden ? '•••' : '${formatMoney(series[point.barIndex].values[point.spotIndex])} ₽'}',
                                TextStyle(color: colorScheme.onInverseSurface),
                              ),
                          ],
                        ),
                      ),
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
            if (!mini)
              Padding(
                padding: EdgeInsets.only(left: axisWidth, right: 12),
                child: SizedBox(
                  height: 25,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final e in ticks.entries)
                        Align(
                          alignment: Alignment(e.key / axisEnd * 2 - 1, 0),
                          child: Text(e.value, style: axisText),
                        ),
                    ],
                  ),
                ),
              ),
            if (mini)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dates.labels.first, style: axisText),
                  if (dates.positions.length > 1)
                    Text(dates.labels.last, style: axisText),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < series.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: color(i)),
                        const SizedBox(width: 5),
                        Text(series[i].name),
                      ],
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

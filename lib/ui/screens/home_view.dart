import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/finance/records.dart';
import '../../domain/reports/home_summary.dart';
import '../../domain/reports/reports.dart';
import '../delta_theme.dart';
import '../finance_format.dart';
import '../messages.dart';
import '../money_visibility.dart';
import '../providers.dart';
import '../reports/report_chart.dart';
import 'finance_screens.dart' show friendlyError;

final _todayHistory = FutureProvider.autoDispose<List<ReportSnapshot>>((
  ref,
) async {
  final data = await ref.watch(reportSnapshotsProvider.future);
  if (data.snapshots.isEmpty) return const [];
  final repo = await ref.watch(repositoryProvider.future);
  final codes = {
    for (final snapshot in data.snapshots)
      for (final position in snapshot.positions) position.currency,
  };
  return homeValuations(data.snapshots, today: await repo.currentRates(codes));
});

class HomeView extends ConsumerStatefulWidget {
  const HomeView({
    required this.overview,
    required this.onNewSnapshot,
    super.key,
  });
  final FinanceOverview overview;
  final VoidCallback onNewSnapshot;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  var today = false;

  @override
  Widget build(BuildContext context) {
    final snapshots = widget.overview.snapshots;
    final draft = snapshots
        .where((item) => item.text('status') == 'draft')
        .firstOrNull;
    final fixed = snapshots
        .where((item) => item.text('status') == 'fixed')
        .firstOrNull;
    final age = fixed == null
        ? null
        : daysSinceSnapshot(fixed.text('date'), DateTime.now());
    final reports = ref.watch(reportSnapshotsProvider);
    final history = today
        ? ref.watch(_todayHistory)
        : reports.whenData((data) => data.snapshots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft != null || age != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppMessage(
              draft == null
                  ? 'Последний слепок $age дней назад'
                  : 'Есть незавершённый слепок от ${displayDate(draft.text('date'), short: true)}',
              kind: MessageKind.warning,
              action: TextButton(
                onPressed: draft == null
                    ? widget.onNewSnapshot
                    : () => context.push('/snapshots/${draft.id}'),
                child: Text(draft == null ? 'Новый слепок' : 'Продолжить'),
              ),
            ),
          ),
        for (final date in reports.value?.excludedDates ?? const <String>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppMessage(
              'Слепок от ${displayDate(date)} не учтён: обновите его курсы',
              kind: MessageKind.warning,
            ),
          ),
        history.when(
          error: (error, _) => AppMessage(friendlyError(error)),
          loading: () => const LinearProgressIndicator(),
          data: (data) => data.isEmpty
              ? const Text(
                  'Пока нет зафиксированных слепков с актуальными курсами.',
                )
              : _TotalCard(data, today: today),
        ),
        if (reports.value?.snapshots.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('По курсу слепка')),
                ButtonSegment(value: true, label: Text('По сегодняшнему')),
              ],
              selected: {today},
              onSelectionChanged: (selection) =>
                  setState(() => today = selection.single),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Последний слепок: ${displayDate(reports.value!.snapshots.last.date)}',
          ),
        ],
        if (history.asData?.value.lastOrNull case final ReportSnapshot snapshot)
          _HomeBreakdown(snapshot),
      ],
    );
  }
}

class _TotalCard extends ConsumerWidget {
  const _TotalCard(this.snapshots, {required this.today});
  final List<ReportSnapshot> snapshots;
  final bool today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totals = snapshots.last.totals.rubles;
    final change = changeFromPrevious(snapshots);
    final decreased = change != null && change.amount < Decimal.zero;
    String signed(Decimal number) {
      final sign = number < Decimal.zero
          ? '−'
          : number > Decimal.zero
          ? '+'
          : '';
      return '$sign${formatMoney(number.abs(), precision: 2)}';
    }

    Widget ownership(String title, Decimal value, Color color) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 6),
                  Flexible(child: Text(title)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${visibleMoney(ref, value)} ₽',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Итого',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            Text(
              '${visibleMoney(ref, totals.total)} ₽',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            if (change != null)
              Text(
                '${decreased
                    ? '↓ '
                    : change.amount > Decimal.zero
                    ? '↑ '
                    : ''}'
                '${change.percent == null ? '' : '${signed(change.percent!)} % '}'
                '(${amountsHidden(ref) ? '•••' : signed(change.amount)} ₽) с прошлого слепка'
                '${today ? ' · по сегодняшнему курсу' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: decreased
                      ? colors.error
                      : theme.brightness == Brightness.dark
                      ? const Color(0xff9de3aa)
                      : const Color(0xff006627),
                ),
              ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Динамика общего итога. Открыть отчёты',
              child: InkWell(
                key: const ValueKey('home-report-link'),
                onTap: () => context.push('/reports'),
                child: IgnorePointer(
                  child: ReportPlot(
                    snapshots: snapshots,
                    chart: ReportChart.total,
                    mini: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ownership('Семейные', totals.family, familyColor),
                const SizedBox(width: 8),
                ownership('Личные', totals.personal, personalColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBreakdown extends ConsumerWidget {
  const _HomeBreakdown(this.snapshot);
  final ReportSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shares = liquidityShares(snapshot);
    final positions = <String, List<ReportPosition>>{};
    for (final position in snapshot.positions) {
      positions.putIfAbsent(position.storageId, () => []).add(position);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shares.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Ликвидность', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _AllocationBar([
            for (final share in shares) (share.amount, Color(share.color)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final share in shares)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: Color(share.color)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${share.name} · ${visibleMoney(ref, share.amount)} ₽ · ${formatMoney(share.percent, precision: 1)} %',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        if (snapshot.totals.rubles.total > Decimal.zero) ...[
          const SizedBox(height: 24),
          Text('По местам хранения', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          for (final entry in snapshot.totals.byStorageRubles.entries)
            if (entry.value.total != Decimal.zero)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(positions[entry.key]!.first.storageName),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${visibleMoney(ref, entry.value.total)} ₽',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AllocationBar([
                          (entry.value.family, familyColor),
                          (entry.value.personal, personalColor),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'сем. ${visibleMoney(ref, entry.value.family)} ₽ · лич. ${visibleMoney(ref, entry.value.personal)} ₽',
                        ),
                      ],
                    ),
                  ),
                  children: [
                    for (final position in positions[entry.key]!)
                      if (position.amount != Decimal.zero)
                        ListTile(
                          dense: true,
                          title: Text(position.currency),
                          trailing: Text(
                            visibleMoney(
                              ref,
                              position.amount,
                              precision: position.precision,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

class _AllocationBar extends StatelessWidget {
  const _AllocationBar(this.parts);
  final List<(Decimal, Color)> parts;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold(Decimal.zero, (sum, part) => sum + part.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          for (final (amount, color) in parts)
            if (amount > Decimal.zero)
              Expanded(
                flex:
                    ((amount * Decimal.fromInt(100000) / total)
                            .toDouble()
                            .round())
                        .clamp(1, 100000),
                child: SizedBox(height: 7, child: ColoredBox(color: color)),
              ),
        ],
      ),
    );
  }
}

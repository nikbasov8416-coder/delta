import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/finance/records.dart';
import '../providers.dart';
import '../messages.dart';
import '../finance_format.dart';

String rateRecordInfo(FinanceRecord rate) {
  String date(String field) {
    final value = rate.text(field);
    return DateTime.tryParse(value) == null ? '—' : displayDate(value);
  }

  final stored = rate.text('fetched_at');
  final parsed = DateTime.tryParse(stored)?.toLocal();
  final time = parsed == null
      ? ''
      : ' ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  return 'Дата курса: ${date('rate_date')}\nДействует / наблюдение: ${date('effective_at')}\nПолучен: ${date('fetched_at')}$time';
}

class RateRefreshButton extends ConsumerStatefulWidget {
  const RateRefreshButton({required this.id, required this.fixed, super.key});
  final String id;
  final bool fixed;
  @override
  ConsumerState<RateRefreshButton> createState() => _RateRefreshButtonState();
}

class _RateRefreshButtonState extends ConsumerState<RateRefreshButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.refresh),
    label: Text(_busy ? 'Загрузка курсов…' : 'Обновить курсы слепка'),
    onPressed: _busy
        ? null
        : () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Обновить сохранённые курсы?'),
                content: Text(
                  widget.fixed
                      ? 'Ручные и сохранённые курсы будут заменены. Изменения зафиксированного слепка попадут в историю.'
                      : 'Успешно полученные курсы заменят сохранённые, в том числе ручные. При ошибке прежние значения сохранятся.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Обновить'),
                  ),
                ],
              ),
            );
            if (yes != true || !mounted) return;
            setState(() => _busy = true);
            try {
              await (await ref.read(repositoryProvider.future))
                  .refreshSnapshotRates(widget.id);
              if (mounted) refreshFinance(ref, widget.id);
            } catch (e) {
              if (context.mounted) {
                AppMessage.show(
                  context,
                  e is StateError ? e.message : 'Не удалось обновить курсы',
                );
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
  );
}

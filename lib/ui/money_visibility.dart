import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers.dart';
import 'finance_format.dart';
import 'messages.dart';

class AmountsVisibility extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(secretStoreProvider).read('hide_amounts') == 'true';
  Future<bool> toggle() async {
    final next = !(state.asData?.value ?? true);
    state = AsyncData(next);
    try {
      await ref.read(secretStoreProvider).write('hide_amounts', '$next');
      return true;
    } catch (_) {
      state = const AsyncData(true);
      return false;
    }
  }
}

final amountsVisibilityProvider =
    AsyncNotifierProvider<AmountsVisibility, bool>(AmountsVisibility.new);
bool amountsHidden(WidgetRef ref) =>
    ref.watch(amountsVisibilityProvider).asData?.value ?? true;
String formatMoney(Decimal value, {int precision = 2}) =>
    formatDecimal(value, precision: precision, trimZeros: precision > 2);

String exactMoney(Decimal value) {
  final fraction = value.toString().split('.');
  final n = fraction.length == 1 ? 0 : fraction.last.length;
  return formatDecimal(value, precision: n < 2 ? 2 : n);
}

String visibleMoney(WidgetRef ref, Decimal value, {int precision = 2}) =>
    amountsHidden(ref) ? '•••' : formatMoney(value, precision: precision);

class AmountsEye extends ConsumerWidget {
  const AmountsEye({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = amountsHidden(ref);
    return IconButton(
      tooltip: hidden ? 'Показать суммы' : 'Скрыть суммы',
      icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
      onPressed: ref.watch(amountsVisibilityProvider).isLoading
          ? null
          : () async {
              final saved = await ref
                  .read(amountsVisibilityProvider.notifier)
                  .toggle();
              if (!saved && context.mounted) {
                AppMessage.show(
                  context,
                  'Не удалось сохранить настройку. Суммы скрыты.',
                );
              }
            },
    );
  }
}

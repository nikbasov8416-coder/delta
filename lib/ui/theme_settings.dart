import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'messages.dart';
import 'providers.dart';

typedef ThemePreference = ({ThemeMode mode, bool saving});

final themePreferenceProvider =
    AsyncNotifierProvider<ThemeSettingsController, ThemePreference>(
      ThemeSettingsController.new,
    );

class ThemeSettingsController extends AsyncNotifier<ThemePreference> {
  static const storageKey = 'theme_mode';

  @override
  Future<ThemePreference> build() async {
    try {
      final value = await ref.watch(secretStoreProvider).read(storageKey);
      final mode = switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return (mode: mode, saving: false);
    } catch (_) {
      return (mode: ThemeMode.system, saving: false);
    }
  }

  Future<bool> select(ThemeMode mode) async {
    final previous = state.asData?.value;
    if (previous == null || previous.saving || previous.mode == mode) {
      return true;
    }
    state = AsyncData((mode: mode, saving: true));
    try {
      await ref.read(secretStoreProvider).write(storageKey, mode.name);
      if (ref.mounted) state = AsyncData((mode: mode, saving: false));
      return true;
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      return false;
    }
  }
}

class ThemeSettings extends ConsumerWidget {
  const ThemeSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider).asData?.value;
    final mode = preference?.mode ?? ThemeMode.system;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DropdownButtonFormField<ThemeMode>(
            key: ValueKey(mode),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Оформление'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Как в системе'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Светлая')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
            ],
            onChanged: preference == null || preference.saving
                ? null
                : (mode) async {
                    if (mode == null) return;
                    final saved = await ref
                        .read(themePreferenceProvider.notifier)
                        .select(mode);
                    if (!saved && context.mounted) {
                      AppMessage.show(
                        context,
                        'Не удалось сохранить оформление.',
                      );
                    }
                  },
          ),
        ),
      ),
    );
  }
}

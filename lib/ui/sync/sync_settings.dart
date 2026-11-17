import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_service.dart';
import '../providers.dart';

const syncLossWarning =
    'Потеря парольной фразы означает, что восстановить данные с Диска нельзя. Сохраните фразу в менеджере паролей.';

class SyncSettings extends ConsumerWidget {
  const SyncSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(syncServiceProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) =>
            const Text('Настройки синхронизации временно недоступны.'),
        data: (service) => service == null
            ? const SizedBox.shrink()
            : ListenableBuilder(
                listenable: service,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Синхронизация через Яндекс Диск',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Последняя синхронизация: ${service.lastSync?.toLocal().toString().split('.').first ?? 'ещё не выполнялась'}',
                    ),
                    if (service.busy) const LinearProgressIndicator(),
                    if (service.error != null) Text(service.error!),
                    if (service.enabled)
                      FilledButton(
                        onPressed: service.busy ? null : service.synchronize,
                        child: const Text('Синхронизировать сейчас'),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: service.busy
                              ? null
                              : () => _open(context, service, true),
                          child: const Text('Создать синхронизацию'),
                        ),
                        OutlinedButton(
                          onPressed: service.busy
                              ? null
                              : () => _open(context, service, false),
                          child: const Text('Подключиться'),
                        ),
                      ],
                    ),
                    const Text(syncLossWarning),
                    const Divider(),
                  ],
                ),
              ),
      );
  Future<void> _open(
    BuildContext context,
    SyncService service,
    bool create,
  ) async {
    final hasData = await service.hasLocalData();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _Connect(service: service, create: create, hasData: hasData),
    );
  }
}

class _Connect extends StatefulWidget {
  const _Connect({
    required this.service,
    required this.create,
    required this.hasData,
  });
  final SyncService service;
  final bool create, hasData;
  @override
  State<_Connect> createState() => _ConnectState();
}

class _ConnectState extends State<_Connect> {
  final login = TextEditingController(),
      password = TextEditingController(),
      phrase = TextEditingController(),
      confirmation = TextEditingController();
  bool replace = true, accepted = false, busy = false;
  String? error;
  Future<void> _submit() async {
    if (widget.create && phrase.text != confirmation.text) {
      setState(() => error = 'Парольные фразы не совпадают.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.configure(
        login: login.text,
        password: password.text,
        phrase: phrase.text,
        create: widget.create,
        replace: replace,
      );
      if (!mounted) return;
      if (widget.service.error == null) {
        Navigator.pop(context);
        return;
      }
      setState(() => error = widget.service.error);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось настроить синхронизацию. Повторите позже.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.create ? 'Создать синхронизацию' : 'Подключиться к Диску',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Используйте логин Яндекса и отдельный пароль приложения для Диска.',
              ),
              TextField(
                controller: login,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Логин Яндекса'),
              ),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль приложения Яндекса',
                ),
              ),
              TextField(
                controller: phrase,
                enabled: !busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Парольная фраза синхронизации (от 12 символов)',
                ),
              ),
              if (widget.create)
                TextField(
                  controller: confirmation,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Повторите парольную фразу',
                  ),
                ),
              if (!widget.create && widget.hasData) ...[
                const Text(
                  'На устройстве есть локальные данные и справочники. Замена удалит локальные финансовые данные и незагруженные изменения. Настройки безопасности сохранятся.',
                ),
                DropdownButtonFormField<bool>(
                  isExpanded: true,
                  initialValue: true,
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text('Заменить данными с Диска'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Объединить по времени изменений'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => replace = v ?? true),
                ),
              ],
              const Text(syncLossWarning),
              CheckboxListTile(
                value: accepted,
                onChanged: busy
                    ? null
                    : (v) => setState(() => accepted = v ?? false),
                title: const Text(
                  'Я сохранил фразу и понимаю выбранное действие',
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: busy || !accepted ? null : _submit,
          child: Text(widget.create ? 'Создать' : 'Подключиться'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    login.dispose();
    password.dispose();
    phrase.dispose();
    confirmation.dispose();
    super.dispose();
  }
}

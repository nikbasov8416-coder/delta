import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'yandex_oauth.dart';

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
  final token = TextEditingController(),
      phrase = TextEditingController(),
      confirmation = TextEditingController();
  bool replace = true, accepted = false, busy = false;
  String? error;
  Future<void> _oauthLink() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Войти через Яндекс'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Скопируйте ссылку и откройте её в браузере. После разрешения доступа скопируйте токен со страницы Яндекса и вставьте его в Delta.',
              ),
              SelectableText(yandexAuthorizationUri.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: yandexAuthorizationUri.toString()),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Скопировать ссылку'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

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
        token: token.text,
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
                'Войдите через Яндекс в браузере, разрешите доступ к папке приложения и вставьте полученный токен. Пароль Яндекса сюда вводить не нужно.',
              ),
              OutlinedButton(
                onPressed: busy ? null : _oauthLink,
                child: const Text('Войти через Яндекс'),
              ),
              TextField(
                controller: token,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'OAuth-токен Яндекса',
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
    token.dispose();
    phrase.dispose();
    confirmation.dispose();
    super.dispose();
  }
}

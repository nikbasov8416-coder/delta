import '../messages.dart';
import '../finance_format.dart';

import 'package:decimal/decimal.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'yandex_oauth.dart';
import 'sync_help.dart';

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
            const AppMessage('Настройки синхронизации временно недоступны.'),
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
                      'Последняя синхронизация: ${service.lastSync == null ? 'ещё не выполнялась' : displayDateTime(service.lastSync!.toIso8601String())}',
                    ),
                    if (service.journalStats case final stats?)
                      Text(
                        'Журнал на Диске: ${stats.files} файлов, '
                        '${formatDecimal(Decimal.fromInt(stats.bytes) * Decimal.parse('0.000001'))} МБ',
                      ),
                    if (service.hasPendingChanges && service.hasConfiguration)
                      const AppMessage(
                        'Есть неотправленные изменения',
                        kind: MessageKind.warning,
                      ),
                    if (service.busy) const LinearProgressIndicator(),
                    if (service.error != null) AppMessage(service.error!),
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
                    if (service.enabled)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: service.busy
                                ? null
                                : () => _maintenance(context, service, false),
                            child: const Text('Обновить вход в Яндекс'),
                          ),
                          TextButton(
                            onPressed: service.busy
                                ? null
                                : service.phraseChangePending
                                ? service.synchronize
                                : () => _maintenance(context, service, true),
                            child: Text(
                              service.phraseChangePending
                                  ? service.replacingDisk
                                        ? 'Продолжить замену на Диске'
                                        : 'Продолжить смену фразы'
                                  : 'Сменить парольную фразу',
                            ),
                          ),
                        ],
                      ),
                    if (service.hasConfiguration)
                      TextButton(
                        onPressed: service.busy
                            ? null
                            : () => _disconnect(context, service),
                        child: const Text(
                          'Отключить синхронизацию на этом устройстве',
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SyncHelp(),
                        ),
                      ),
                      child: const Text('Редкие ситуации'),
                    ),
                    const Text(syncLossWarning),
                    const Divider(),
                  ],
                ),
              ),
      );
  Future<void> _disconnect(BuildContext context, SyncService service) async {
    final pending = await service.refreshPending();
    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Отключить синхронизацию на этом устройстве?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Финансовые данные останутся на устройстве. Файлы на Диске сохранятся.',
            ),
            if (pending)
              const AppMessage(
                'Есть неотправленные изменения. Сначала синхронизируйте устройство, чтобы они появились на Диске.',
                kind: MessageKind.warning,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          if (pending && service.enabled)
            TextButton(
              onPressed: () => Navigator.pop(dialog, 'sync'),
              child: const Text('Сначала синхронизировать'),
            ),
          FilledButton(
            style: destructiveStyle(dialog),
            onPressed: () => Navigator.pop(dialog, 'disconnect'),
            child: Text(pending ? 'Всё равно отключить' : 'Отключить'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'sync') {
      await service.synchronize();
    } else {
      await service.disconnect(discardPending: pending);
      if (context.mounted && service.error == null) {
        AppMessage.show(
          context,
          'Синхронизация отключена.',
          kind: MessageKind.success,
        );
      }
    }
  }

  Future<void> _maintenance(
    BuildContext context,
    SyncService service,
    bool phrase,
  ) async {
    final first = TextEditingController(), second = TextEditingController();
    bool accepted = false, working = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !working,
          child: AlertDialog(
            title: Text(
              phrase ? 'Сменить парольную фразу' : 'Обновить вход в Яндекс',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (phrase)
                    const Text(
                      'Сначала синхронизируйте остальные устройства, их неотправленные изменения иначе потеряются. После смены подключите их заново с новой фразой. Дождитесь завершения; при обрыве смена продолжится после следующего входа.',
                    ),
                  if (!phrase)
                    SelectableText(yandexAuthorizationUri.toString()),
                  TextField(
                    controller: first,
                    obscureText: true,
                    enabled: !working,
                    decoration: InputDecoration(
                      labelText: phrase
                          ? 'Новая фраза (от 12 символов)'
                          : 'Новый OAuth-токен',
                    ),
                  ),
                  if (phrase)
                    TextField(
                      controller: second,
                      obscureText: true,
                      enabled: !working,
                      decoration: const InputDecoration(
                        labelText: 'Повторите новую фразу',
                      ),
                    ),
                  if (phrase)
                    CheckboxListTile(
                      value: accepted,
                      onChanged: working
                          ? null
                          : (v) => setState(() => accepted = v ?? false),
                      title: const Text(
                        'Фраза сохранена; остальные устройства синхронизированы',
                      ),
                    ),
                  if (error != null) AppMessage(error!),
                  if (working) const LinearProgressIndicator(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: working ? null : () => Navigator.pop(dialog),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: phrase ? destructiveStyle(context) : null,
                onPressed: working || phrase && !accepted
                    ? null
                    : () async {
                        if (phrase && first.text != second.text) {
                          setState(() => error = 'Фразы не совпадают.');
                          return;
                        }
                        setState(() => working = true);
                        try {
                          if (phrase) {
                            await service.changePhrase(first.text);
                          } else {
                            await service.refreshToken(first.text);
                          }
                          if (!dialog.mounted) return;
                          if (service.error == null) {
                            Navigator.pop(dialog);
                          } else {
                            setState(() => error = service.error);
                          }
                        } finally {
                          if (dialog.mounted) setState(() => working = false);
                        }
                      },
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
    first.dispose();
    second.dispose();
  }

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

enum _JoinMode { fromDisk, merge, fromDevice }

class _ConnectState extends State<_Connect> {
  final token = TextEditingController(),
      phrase = TextEditingController(),
      confirmation = TextEditingController();
  var mode = _JoinMode.fromDisk;
  bool accepted = false, busy = false;
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
        replace: mode == _JoinMode.fromDisk,
        replaceFromDevice: mode == _JoinMode.fromDevice,
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
                if (mode == _JoinMode.fromDisk)
                  const AppMessage(
                    'Замена удалит локальные финансовые данные и незагруженные изменения. Настройки безопасности сохранятся.',
                    kind: MessageKind.warning,
                  ),
                if (mode == _JoinMode.fromDevice)
                  const AppMessage(
                    'Текущие данные на Диске будут заменены данными этого устройства. '
                    'Остальные устройства нужно подключить заново.',
                    kind: MessageKind.warning,
                  ),
                DropdownButtonFormField<_JoinMode>(
                  isExpanded: true,
                  initialValue: _JoinMode.fromDisk,
                  items: [
                    const DropdownMenuItem(
                      value: _JoinMode.fromDisk,
                      child: Text(
                        'Заменить данными с Диска',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _JoinMode.merge,
                      child: Text(
                        'Объединить по времени изменений',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.service.hasConfiguration)
                      const DropdownMenuItem(
                        value: _JoinMode.fromDevice,
                        child: Text(
                          'Заменить данными этого устройства',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          mode = value ?? _JoinMode.fromDisk;
                          accepted = false;
                        }),
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
              if (error != null) AppMessage(error!),
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
          style: !widget.create && widget.hasData && mode != _JoinMode.merge
              ? destructiveStyle(context)
              : null,
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

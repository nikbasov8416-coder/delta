import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/backup/finance_copy.dart';
import '../../data/backup/finance_excel.dart';
import '../../data/sync/sync_error.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/rates/rates.dart';
import '../file_dialogs.dart';
import '../finance_format.dart';
import '../messages.dart';
import '../providers.dart';

class DataFilesView extends ConsumerStatefulWidget {
  const DataFilesView({required this.export, super.key});
  final bool export;

  @override
  ConsumerState<DataFilesView> createState() => _DataFilesViewState();
}

class _DataFilesViewState extends ConsumerState<DataFilesView> {
  bool _busy = false;
  String? _error;
  bool _restored = false;

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            BackupFailure e => e.message,
            SyncFailure e => e.message,
            PlatformException e =>
              e.message ?? 'Не удалось открыть диалог выбора файла.',
            _ => 'Не удалось выполнить операцию с файлом.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _password({required bool create}) => showDialog<String>(
    context: context,
    builder: (_) => _BackupPassword(create: create),
  );

  Future<void> _create(SyncService service) => _run(() async {
    final password = await _password(create: true);
    if (password == null || !mounted) return;
    final dialogs = ref.read(fileDialogsProvider);
    final bytes = await FinanceCopy(service).create(password);
    if (!mounted) return;
    final name = 'delta-backup-${dayKey(service.repository.now())}.delta';
    if (await dialogs.save(name, bytes) && mounted) {
      AppMessage.show(
        context,
        'Резервная копия сохранена.',
        kind: MessageKind.success,
      );
    }
  });

  Future<void> _restore(SyncService service) => _run(() async {
    final dialogs = ref.read(fileDialogsProvider);
    final bytes = await dialogs.openBackup();
    if (bytes == null || !mounted) return;
    final password = await _password(create: false);
    if (password == null || !mounted) return;
    final copy = FinanceCopy(service);
    final backup = await copy.open(bytes, password);
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Восстановить резервную копию?'),
        content: Text(
          'Создана ${displayDate(backup.createdAt.toLocal().toIso8601String())}\n'
          'Слепков: ${backup.snapshots}\nМест хранения: ${backup.storages}\n'
          'Последний слепок: ${backup.lastSnapshot == null ? '—' : displayDate(backup.lastSnapshot!)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructiveStyle(dialog),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Заменить все данные на этом устройстве'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await copy.restore(backup);
    if (!mounted) return;
    refreshFinance(ref);
    ref.invalidate(snapshotProvider);
    setState(() => _restored = true);
    AppMessage.show(
      context,
      'Данные восстановлены.',
      kind: MessageKind.success,
    );
  });

  Future<void> _export(SyncService service) => _run(() async {
    final dialogs = ref.read(fileDialogsProvider);
    final bytes = await exportFinanceExcel(service.repository);
    if (!mounted) return;
    final name = 'delta-export-${dayKey(service.repository.now())}.xlsx';
    if (await dialogs.save(name, bytes) && mounted) {
      AppMessage.show(
        context,
        'Файл Excel сохранён.',
        kind: MessageKind.success,
      );
    }
  });

  @override
  Widget build(BuildContext context) => ref
      .watch(syncServiceProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) =>
            const AppMessage('Не удалось открыть данные приложения.'),
        data: (service) => service == null
            ? const AppMessage('Операции с файлами временно недоступны.')
            : ListenableBuilder(
                listenable: service,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) AppMessage(_error!),
                    if (_busy && ModalRoute.isCurrentOf(context) == true)
                      const LinearProgressIndicator(),
                    if (widget.export) ...[
                      const AppMessage(
                        'Файл не зашифрован — храните его аккуратно.',
                        kind: MessageKind.warning,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : () => _export(service),
                        child: const Text('Сохранить Excel'),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy ? null : () => _create(service),
                            child: const Text('Создать'),
                          ),
                          OutlinedButton(
                            onPressed:
                                _busy ||
                                    service.hasConfiguration ||
                                    service.busy
                                ? null
                                : () => _restore(service),
                            child: const Text('Восстановить из файла'),
                          ),
                        ],
                      ),
                      if (service.hasConfiguration)
                        AppMessage(
                          'Чтобы восстановить из файла, сначала отключите синхронизацию на этом устройстве',
                          kind: MessageKind.warning,
                          action: TextButton(
                            onPressed: () => context.push('/settings'),
                            child: const Text('Настройки синхронизации'),
                          ),
                        ),
                      if (_restored)
                        const AppMessage(
                          'Чтобы данные появились на других устройствах, создайте новую синхронизацию '
                          'или подключитесь с заменой данными этого устройства.',
                          kind: MessageKind.warning,
                        ),
                    ],
                  ],
                ),
              ),
      );
}

class _BackupPassword extends StatefulWidget {
  const _BackupPassword({required this.create});
  final bool create;

  @override
  State<_BackupPassword> createState() => _BackupPasswordState();
}

class _BackupPasswordState extends State<_BackupPassword> {
  final _first = TextEditingController(), _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    if (_first.text.isEmpty) {
      setState(() => _error = 'Введите пароль копии.');
    } else if (widget.create && _first.text != _second.text) {
      setState(() => _error = 'Пароли не совпадают.');
    } else {
      Navigator.pop(context, _first.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.create ? 'Пароль резервной копии' : 'Открыть резервную копию',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.create)
            const AppMessage(
              'Это отдельный пароль, не PIN и не фраза синхронизации. Если его потерять, копию открыть не получится.',
              kind: MessageKind.warning,
            ),
          TextField(
            controller: _first,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Пароль копии'),
            onSubmitted: widget.create ? null : (_) => _submit(),
          ),
          if (widget.create)
            TextField(
              controller: _second,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Повторите пароль'),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null) AppMessage(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.create ? 'Продолжить' : 'Открыть'),
      ),
    ],
  );
}

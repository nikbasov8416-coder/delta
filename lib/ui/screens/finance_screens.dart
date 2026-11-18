import '../sync/sync_settings.dart';
import '../money_visibility.dart';
import '../reports/reports_screen.dart';
import '../finance_format.dart';
import '../messages.dart';
import 'home_view.dart';
import 'data_files.dart';
import '../file_dialogs.dart';

import 'package:decimal/decimal.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/default_catalog.dart';
import '../../domain/finance/finance_repository.dart';
import '../../domain/finance/records.dart';
import '../../domain/snapshots/snapshot_totals.dart';
import '../../domain/rates/rates.dart';
import '../navigation/app_routes.dart';
import '../providers.dart';
import 'rate_refresh_button.dart';

String friendlyError(Object error) => switch (error) {
  FormatException e => e.message,
  ArgumentError e => e.message?.toString() ?? 'Проверьте введённые значения',
  RateFailure e => e.message,
  StateError e => e.message,
  _ =>
    'Не удалось выполнить действие. Проверьте данные; изменения не сохранены.',
};

class EditField {
  const EditField(
    this.key,
    this.label, {
    this.initial = '',
    this.options,
    this.numeric = false,
    this.date = false,
  });
  final String key, label, initial;
  final Map<String, String>? options;
  final bool numeric, date;
  bool get amount =>
      numeric && const ['amount', 'family', 'rate'].contains(key);
}

Future<void> editDialog(
  BuildContext context,
  String title,
  List<EditField> fields,
  Future<void> Function(Map<String, String>, Set<String>) save, {
  Map<String, String> choices = const {},
  Set<String> selected = const {},
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _EditorDialog(
    title: title,
    fields: fields,
    save: save,
    choices: choices,
    selected: selected,
  ),
);

class _EditorDialog extends ConsumerStatefulWidget {
  const _EditorDialog({
    required this.title,
    required this.fields,
    required this.save,
    required this.choices,
    required this.selected,
  });
  final String title;
  final List<EditField> fields;
  final Future<void> Function(Map<String, String>, Set<String>) save;
  final Map<String, String> choices;
  final Set<String> selected;
  @override
  ConsumerState<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends ConsumerState<_EditorDialog> {
  late final Map<String, TextEditingController> controllers;
  late final Set<String> selection;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.fields)
        field.key: TextEditingController(
          text: field.amount
              ? AmountInputFormatter.group(field.initial)
              : field.initial,
        ),
    };
    selection = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.date
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: AnimatedBuilder(
                          animation: controllers[field.key]!,
                          builder: (_, _) =>
                              Text(displayDate(controllers[field.key]!.text)),
                        ),
                        onPressed: busy
                            ? null
                            : () async {
                                final controller = controllers[field.key]!;
                                final initial = DateTime.parse(controller.text);
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(
                                    initial.year < 1900 ? initial.year : 1900,
                                  ),
                                  lastDate: DateTime(
                                    initial.year > 2200 ? initial.year : 2200,
                                    12,
                                    31,
                                  ),
                                );
                                if (date != null && mounted) {
                                  controller.text = dayKey(date);
                                }
                              },
                      )
                    : field.options == null
                    ? TextField(
                        controller: controllers[field.key],
                        inputFormatters: field.amount
                            ? const [AmountInputFormatter()]
                            : null,
                        enabled: !busy,
                        obscureText:
                            field.numeric &&
                            ['amount', 'family', 'rate'].contains(field.key) &&
                            amountsHidden(ref),
                        keyboardType: field.numeric
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: field.label),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: field.initial.isEmpty
                            ? null
                            : field.initial,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: field.label),
                        items: field.options!.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) =>
                                  controllers[field.key]!.text = value ?? '',
                      ),
              ),
            if (widget.choices.isNotEmpty) const Text('Валюты места хранения'),
            for (final entry in widget.choices.entries)
              CheckboxListTile(
                title: Text(entry.value),
                value: selection.contains(entry.key),
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          selection.add(entry.key);
                        } else {
                          selection.remove(entry.key);
                        }
                      }),
              ),
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
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await widget.save({
                    for (final e in controllers.entries) e.key: e.value.text,
                  }, selection);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    setState(() => error = friendlyError(e));
                  }
                } finally {
                  if (context.mounted) setState(() => busy = false);
                }
              },
        child: Text(busy ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class FinanceScaffold extends StatelessWidget {
  const FinanceScaffold({
    required this.title,
    required this.child,
    required this.section,
    this.onNewSnapshot,
    this.leading,
    super.key,
  });
  final String title, section;
  final Widget child;
  final VoidCallback? onNewSnapshot;
  final Widget? leading;

  static const destinations = [
    ('/', 'Главная', Icons.home_outlined),
    ('/snapshots', 'Слепки', Icons.account_balance_wallet_outlined),
    ('/reports', 'Отчёты', Icons.insights_outlined),
    ('/more', 'Ещё', Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final index = destinations.indexWhere((item) => item.$1 == section);
      final selected = index == -1 ? 3 : index;
      void navigate(int i) => context.go(destinations[i].$1);
      final create = onNewSnapshot == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onNewSnapshot,
              icon: const Icon(Icons.add),
              label: const Text('Новый слепок'),
            );
      final content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: section == '/reports' ? 1200 : 840,
          ),
          child: child,
        ),
      );
      return Scaffold(
        appBar: AppBar(
          leading: leading,
          title: Text(title),
          actions: const [AmountsEye()],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: navigate,
                destinations: [
                  for (final (_, label, icon) in destinations)
                    NavigationDestination(icon: Icon(icon), label: label),
                ],
              ),
        floatingActionButton: wide ? null : create,
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: navigate,
                    groupAlignment: -1,
                    labelType: NavigationRailLabelType.all,
                    leading: create == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: create,
                          ),
                    destinations: [
                      for (final (_, label, icon) in destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          label: Text(label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      );
    },
  );
}

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({required this.section, super.key});
  final String section;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FinanceScaffold(
    section: section,
    title: appScreens[section] ?? 'Delta',
    onNewSnapshot: section == '/' || section == '/snapshots'
        ? () => _newSnapshot(context, ref)
        : null,
    child: ref
        .watch(overviewProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: AppMessage(friendlyError(error))),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 86),
            children: switch (section) {
              '/storage' => _storage(context, ref, data),
              '/catalogs' => _catalogs(context, ref, data),
              '/snapshots' => _snapshots(context, ref, data),
              '/settings' => [const SyncSettings(), const SecuritySettings()],
              '/reports' => [const ReportsView()],
              '/backup' => [const DataFilesView(export: false)],
              '/export' => [const DataFilesView(export: true)],
              '/more' => [
                for (final path in [
                  '/storage',
                  '/catalogs',
                  '/settings',
                  '/backup',
                  '/export',
                ])
                  ListTile(
                    title: Text(appScreens[path]!),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(path),
                  ),
                ref
                    .watch(applicationVersionProvider)
                    .when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const Text('Версия недоступна'),
                      data: (version) => ListTile(title: Text(version)),
                    ),
              ],
              _ => [
                HomeView(
                  overview: data,
                  onNewSnapshot: () => _newSnapshot(context, ref),
                ),
              ],
            },
          ),
        ),
  );

  Future<FinanceRepository> _repo(WidgetRef ref) =>
      ref.read(repositoryProvider.future);
  Future<void> _newSnapshot(BuildContext context, WidgetRef ref) async {
    String? result;
    await editDialog(
      context,
      'Новый слепок',
      [
        EditField(
          'date',
          'Дата',
          date: true,
          initial: DateTime.now().toIso8601String().substring(0, 10),
        ),
        const EditField('note', 'Заметка'),
      ],
      (values, _) async {
        result = await (await _repo(ref))
            .createSnapshot(values['date']!, values['note']!);
        refreshFinance(ref);
      },
    );
    if (result != null && context.mounted) context.push('/snapshots/$result');
  }

  List<Widget> _snapshots(
    BuildContext context,
    WidgetRef ref,
    FinanceOverview data,
  ) => [
    for (final item in data.snapshots)
      Card(
        child: ListTile(
          title: Text(displayDate(item.text('date'))),
          subtitle: Text(
            '${item.text('status') == 'fixed' ? 'Зафиксирован' : 'Черновик'} · ${item.text('note')}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/snapshots/${item.id}'),
        ),
      ),
  ];
  Future<void> _editStorage(
    BuildContext context,
    WidgetRef ref,
    FinanceOverview data, [
    FinanceRecord? item,
  ]) async {
    if (data.liquidity.isEmpty || data.currencies.isEmpty) {
      AppMessage.show(
        context,
        'Сначала заполните справочники',
        kind: MessageKind.warning,
      );
      return;
    }
    const types = {
      'account': 'Счёт',
      'card': 'Карта',
      'cash': 'Наличные',
      'deposit': 'Вклад',
      'broker': 'Брокерский счёт',
      'crypto': 'Криптокошелёк',
      'insurance': 'Страховой продукт',
      'other': 'Прочее',
    };
    await editDialog(
      context,
      item == null ? 'Новое место хранения' : 'Место хранения',
      [
        EditField('name', 'Название', initial: item?.text('name') ?? ''),
        EditField(
          'type',
          'Тип',
          initial: item?.text('type') ?? 'account',
          options: types,
        ),
        EditField(
          'liquidity',
          'Ликвидность места целиком',
          initial: item?.text('liquidity_id') ?? data.liquidity.first.id,
          options: {for (final l in data.liquidity) l.id: l.text('name')},
        ),
        EditField(
          'organization',
          'Организация',
          initial: item?.text('organization') ?? '',
        ),
        EditField('note', 'Заметка', initial: item?.text('note') ?? ''),
        EditField(
          'archived',
          'Архив',
          initial: item?.flag('archived') == true ? '1' : '0',
          options: const {'0': 'Активно', '1': 'В архиве'},
        ),
      ],
      (values, selection) async {
        await (await _repo(ref)).saveStorage(
          id: item?.id,
          name: values['name']!,
          type: values['type']!,
          liquidityId: values['liquidity']!,
          organization: values['organization']!,
          note: values['note']!,
          archived: values['archived'] == '1',
          currencyIds: selection.toList(),
        );
        refreshFinance(ref);
      },
      choices: {for (final c in data.currencies) c.id: c.text('code')},
      selected: data.storageCurrencies
          .where((p) => p.text('storage_id') == item?.id && p.flag('active'))
          .map((p) => p.text('currency_id'))
          .toSet(),
    );
  }

  List<Widget> _storage(
    BuildContext context,
    WidgetRef ref,
    FinanceOverview data,
  ) => [
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: () => _editStorage(context, ref, data),
        child: const Text('Добавить место хранения'),
      ),
    ),
    for (final item in data.storages)
      Card(
        child: ListTile(
          title: Text(
            '${item.text('name')}${item.flag('archived') ? ' · архив' : ''}',
          ),
          subtitle: Text(
            '${item.text('liquidity_name')} · ${data.currencies.where((c) => data.storageCurrencies.any((p) => p.text('storage_id') == item.id && p.text('currency_id') == c.id && p.flag('active'))).map((c) => c.text('code')).join(', ')}',
          ),
          trailing: const Icon(Icons.edit),
          onTap: () => _editStorage(context, ref, data, item),
        ),
      ),
  ];
  Future<void> _currency(
    BuildContext context,
    WidgetRef ref, [
    FinanceRecord? item,
  ]) => editDialog(
    context,
    'Валюта',
    [
      EditField('code', 'Код', initial: item?.text('code') ?? ''),
      EditField('name', 'Название', initial: item?.text('name') ?? ''),
      EditField(
        'kind',
        'Вид',
        initial: item?.text('kind') ?? 'fiat',
        options: const {'fiat': 'Обычная валюта', 'crypto': 'Криптовалюта'},
      ),
      EditField(
        'precision',
        'Знаков после запятой',
        initial: item?.text('precision') ?? '2',
        numeric: true,
      ),
    ],
    (v, _) async {
      await (await _repo(ref)).saveCurrency(
        id: item?.id,
        code: v['code']!,
        name: v['name']!,
        kind: v['kind']!,
        precision: int.tryParse(v['precision']!) ?? -1,
      );
      refreshFinance(ref);
    },
  );
  Future<void> _liquidity(
    BuildContext context,
    WidgetRef ref, [
    FinanceRecord? item,
  ]) => editDialog(
    context,
    'Уровень ликвидности',
    [
      EditField('name', 'Название', initial: item?.text('name') ?? ''),
      EditField(
        'order',
        'Порядок',
        initial: item?.text('sort_order') ?? '0',
        numeric: true,
      ),
      EditField(
        'color',
        'Цвет',
        initial: item?.text('color') ?? liquidityColors.keys.first.toString(),
        options: {
          for (final entry in liquidityColorChoices.entries)
            entry.key.toString(): entry.value,
          if (item != null &&
              !liquidityColorChoices.containsKey(item.number('color')))
            item.text('color'): 'Текущий цвет',
        },
      ),
    ],
    (v, _) async {
      await (await _repo(ref)).saveLiquidity(
        id: item?.id,
        name: v['name']!,
        order: int.parse(v['order']!),
        color: int.parse(v['color']!),
      );
      refreshFinance(ref);
    },
  );
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String catalog,
    FinanceRecord item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из справочника?'),
        content: Text(item.text('name')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructiveStyle(ctx),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await (await _repo(ref)).removeCatalogEntry(catalog, item.id);
      refreshFinance(ref);
    } catch (e) {
      if (context.mounted) {
        AppMessage.show(context, friendlyError(e));
      }
    }
  }

  List<Widget> _catalogs(
    BuildContext context,
    WidgetRef ref,
    FinanceOverview data,
  ) => [
    Text('Валюты', style: Theme.of(context).textTheme.titleLarge),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => _currency(context, ref),
        child: const Text('Добавить валюту'),
      ),
    ),
    for (final item in data.currencies)
      ListTile(
        title: Text('${item.text('code')} · ${item.text('name')}'),
        subtitle: Text('Точность: ${item.number('precision')}'),
        onTap: () => _currency(context, ref, item),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(context, ref, 'currency', item),
        ),
      ),
    const Divider(),
    Text('Ликвидность', style: Theme.of(context).textTheme.titleLarge),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => _liquidity(context, ref),
        child: const Text('Добавить уровень'),
      ),
    ),
    for (final item in data.liquidity)
      ListTile(
        leading: Icon(Icons.circle, color: Color(item.number('color'))),
        title: Text(item.text('name')),
        subtitle: Text('Порядок: ${item.number('sort_order')}'),
        onTap: () => _liquidity(context, ref, item),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(context, ref, 'liquidity_level', item),
        ),
      ),
  ];
}

class SnapshotScreen extends ConsumerWidget {
  const SnapshotScreen({required this.id, super.key});
  final String id;
  Future<FinanceRepository> _repo(WidgetRef ref) =>
      ref.read(repositoryProvider.future);
  @override
  Widget build(BuildContext context, WidgetRef ref) => FinanceScaffold(
    title: 'Слепок',
    section: '/snapshots',
    leading: BackButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/snapshots');
        }
      },
    ),
    child: ref
        .watch(snapshotProvider(id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: AppMessage(friendlyError(e))),
          data: (detail) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    displayDate(detail.header.text('date')),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Chip(
                    backgroundColor: detail.header.text('status') == 'fixed'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.tertiaryContainer,
                    label: Text(
                      detail.header.text('status') == 'fixed'
                          ? 'Зафиксирован'
                          : 'Черновик',
                    ),
                  ),
                ],
              ),
              Text(detail.header.text('note')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => editDialog(
                    context,
                    'Дата и заметка',
                    [
                      EditField(
                        'date',
                        'Дата',
                        date: true,
                        initial: detail.header.text('date'),
                      ),
                      EditField(
                        'note',
                        'Заметка',
                        initial: detail.header.text('note'),
                      ),
                    ],
                    (v, _) async {
                      await (await _repo(ref))
                          .saveSnapshotHeader(id, v['date']!, v['note']!);
                      refreshFinance(ref, id);
                    },
                  ),
                  child: const Text('Изменить дату и заметку'),
                ),
              ),
              Text(
                'Заполнено ${detail.lines.where((l) => l.flag('confirmed')).length} из ${detail.lines.length}',
              ),
              LinearProgressIndicator(
                value: detail.lines.isEmpty
                    ? 0
                    : detail.lines.where((l) => l.flag('confirmed')).length /
                          detail.lines.length,
              ),
              if (detail.header.text('status') == 'draft')
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Точно подтвердить все непроверенные?',
                          ),
                          content: const Text(
                            'Подтвердятся только строки с уже заполненными суммами. Пустые строки нужно заполнить отдельно.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Да, подтвердить'),
                            ),
                          ],
                        ),
                      );
                      if (yes != true) return;
                      try {
                        await (await _repo(ref)).confirmUnreviewed(id);
                        refreshFinance(ref, id);
                      } catch (e) {
                        if (context.mounted) {
                          AppMessage.show(context, friendlyError(e));
                        }
                      }
                    },
                    child: const Text('Подтвердить все непроверенные'),
                  ),
                ),
              if (detail.header.text('status') == 'fixed')
                const Text(
                  'Изменения сумм, курсов, даты и заметок записываются в историю.',
                ),
              ..._positionGroups(context, ref, detail),
              const Divider(),
              Text(
                'Курсы к рублю',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Автоматические курсы на дату слепка. При сбое доступен ручной ввод. RUB = 1.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: RateRefreshButton(
                  id: id,
                  fixed: detail.header.text('status') == 'fixed',
                ),
              ),
              for (final error in detail.rateErrors.entries)
                AppMessage('${error.key}: ${error.value}'),
              for (final currencyId
                  in detail.lines.map((l) => l.text('currency_id')).toSet())
                _rate(context, ref, detail, currencyId),
              if (detail.header.text('status') == 'draft')
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await (await _repo(ref)).finalizeSnapshot(id);
                        refreshFinance(ref, id);
                      } catch (e) {
                        if (context.mounted) {
                          AppMessage.show(context, friendlyError(e));
                        }
                      }
                    },
                    child: const Text('Зафиксировать слепок'),
                  ),
                ),
              const Divider(),
              TotalsView(id: id),
              const Divider(),
              Text(
                'История изменений',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (detail.audit.isEmpty)
                const Text('После фиксации изменений пока не было.'),
              for (final entry in detail.audit)
                ExpansionTile(
                  title: Text(displayDateTime(entry.text('changed_at'))),
                  subtitle: Text(_entityLabel(entry.text('entity_type'))),
                  children: _auditChanges(
                    entry,
                    detail.lines,
                    amountsHidden(ref),
                  ),
                ),
            ],
          ),
        ),
  );
  List<Widget> _positionGroups(
    BuildContext context,
    WidgetRef ref,
    SnapshotDetail detail,
  ) {
    final draft = detail.header.text('status') == 'draft';
    final groups = <String, Map<String, List<FinanceRecord>>>{};
    for (final line in detail.lines) {
      if (!draft &&
          (line.values['amount'] == null ||
              line.decimal('amount') == Decimal.zero)) {
        continue;
      }
      final places = groups.putIfAbsent(line.text('liquidity_id'), () => {});
      places.putIfAbsent(line.text('storage_id'), () => []).add(line);
    }
    return [
      for (final places in groups.values) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            places.values.first.first.text('liquidity_name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final place in places.entries)
          _storageCard(context, ref, detail, place.key, place.value),
      ],
    ];
  }

  List<Widget> _auditChanges(
    FinanceRecord entry,
    List<FinanceRecord> lines,
    bool hidden,
  ) {
    final position = lines
        .where((line) => line.id == entry.text('entity_id'))
        .firstOrNull;
    final before = jsonDecode(entry.text('old_value')) as Map<String, dynamic>;
    final after = jsonDecode(entry.text('new_value')) as Map<String, dynamic>;
    const labels = {
      'amount': 'Всего',
      'family_amount': 'Семейные',
      'note': 'Заметка',
      'date': 'Дата',
      'rate': 'Курс',
      'source': 'Источник',
      'fetched_at': 'Время ввода',
      'confirmed': 'Подтверждено',
      'rate_date': 'Дата курса слепка',
      'effective_at': 'Действует / наблюдение',
    };
    String display(String key, Object? value) {
      if (value == null || value == '') return '—';
      if (key == 'source') {
        return rateSourceLabel(value.toString());
      }
      if (key == 'confirmed') return value == 1 ? 'Да' : 'Нет';
      if (['amount', 'family_amount', 'rate'].contains(key)) {
        if (hidden) return '•••';
        final number = Decimal.parse(value.toString());
        if (position == null || key == 'rate') return exactMoney(number);
        return formatMoney(
          number,
          precision: currencyDisplayPrecision(
            position.text('kind'),
            position.number('precision'),
          ),
        );
      }
      if (['date', 'rate_date', 'effective_at', 'fetched_at'].contains(key)) {
        return displayDateTime(value.toString());
      }
      return value.toString();
    }

    return [
      for (final key in labels.keys)
        if (before[key] != after[key])
          Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              '${labels[key]}: ${display(key, before[key])} → ${display(key, after[key])}',
            ),
          ),
    ];
  }

  String _entityLabel(String type) => switch (type) {
    'snapshot_line' => 'Сумма / семейная часть / заметка',
    'snapshot_rate' => 'Курс',
    _ => 'Дата / заметка слепка',
  };
  Widget _storageCard(
    BuildContext context,
    WidgetRef ref,
    SnapshotDetail detail,
    String storageId,
    List<FinanceRecord> lines,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lines.first.text('storage_name'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final line in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  line.flag('confirmed') ? Icons.check_circle : Icons.edit_note,
                ),
                title: Text(
                  '${line.text('code')}: ${line.values['amount'] == null ? 'не заполнено' : visibleMoney(ref, line.decimal('amount'), precision: currencyDisplayPrecision(line.text('kind'), line.number('precision')))}',
                ),
                subtitle: Text(
                  'Семейные: ${visibleMoney(ref, line.decimal('family_amount'), precision: currencyDisplayPrecision(line.text('kind'), line.number('precision')))}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (detail.header.text('status') == 'draft' &&
                        !line.flag('confirmed'))
                      TextButton(
                        key: ValueKey('confirm-${line.id}'),
                        onPressed: line.values['amount'] == null
                            ? null
                            : () async {
                                try {
                                  await (await _repo(ref)).confirmLine(line.id);
                                  refreshFinance(ref, id);
                                } catch (e) {
                                  if (context.mounted) {
                                    AppMessage.show(context, friendlyError(e));
                                  }
                                }
                              },
                        child: const Text('✓ без изменений'),
                      ),
                    Icon(
                      Icons.edit,
                      size: 18,
                      color: detail.header.text('status') == 'fixed'
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
                  ],
                ),
                onTap: () => editDialog(
                  context,
                  'Остаток · ${line.text('code')}',
                  [
                    EditField(
                      'amount',
                      'Всего',
                      initial: line.text('amount').replaceAll('.', ','),
                      numeric: true,
                    ),
                    EditField(
                      'family',
                      'В том числе семейные',
                      initial: line.text('family_amount').replaceAll('.', ','),
                      numeric: true,
                    ),
                    EditField('note', 'Заметка', initial: line.text('note')),
                  ],
                  (v, _) async {
                    await (await _repo(ref)).saveLine(
                      line.id,
                      v['amount']!,
                      v['family']!,
                      v['note']!,
                    );
                    refreshFinance(ref, id);
                  },
                ),
              ),
            if (detail.header.text('status') == 'draft')
              TextButton(
                onPressed: () async {
                  final data = await ref.read(overviewProvider.future);
                  final options = {
                    for (final currency in data.currencies.where(
                      (c) => !lines.any((l) => l.text('currency_id') == c.id),
                    ))
                      currency.id: currency.text('code'),
                  };
                  if (!context.mounted) return;
                  if (options.isEmpty) {
                    AppMessage.show(
                      context,
                      'Все валюты уже добавлены',
                      kind: MessageKind.warning,
                    );
                    return;
                  }
                  await editDialog(
                    context,
                    'Добавить валюту',
                    [
                      EditField(
                        'currency',
                        'Валюта',
                        initial: options.keys.first,
                        options: options,
                      ),
                    ],
                    (v, _) async {
                      await (await _repo(ref))
                          .addSnapshotCurrency(id, storageId, v['currency']!);
                      refreshFinance(ref, id);
                    },
                  );
                },
                child: const Text('Добавить валюту'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rate(
    BuildContext context,
    WidgetRef ref,
    SnapshotDetail detail,
    String currencyId,
  ) {
    final line = detail.lines.firstWhere(
      (l) => l.text('currency_id') == currencyId,
    );
    final matches = detail.rates.where(
      (r) => r.text('currency_id') == currencyId,
    );
    final value = matches.isEmpty
        ? (line.text('code') == 'RUB' ? '1' : '')
        : matches.first.text('rate');
    return ListTile(
      title: Text(
        value.isEmpty
            ? '${line.text('code')} · Введите курс'
            : '${line.text('code')} ${amountsHidden(ref) ? '•••' : exactMoney(Decimal.parse(value))} ₽ · ${matches.isEmpty ? 'Постоянный курс' : compactRateSource(matches.first.text('source'))}',
      ),
      trailing: matches.isEmpty
          ? null
          : _RateInfo(rateRecordInfo(matches.first)),
      onTap: line.text('code') == 'RUB'
          ? null
          : () => editDialog(
              context,
              'Курс ${line.text('code')} к RUB',
              [
                EditField(
                  'rate',
                  'Рублей за одну единицу',
                  initial: value.replaceAll('.', ','),
                  numeric: true,
                ),
              ],
              (v, _) async {
                await (await _repo(ref)).saveRate(id, currencyId, v['rate']!);
                refreshFinance(ref, id);
              },
            ),
    );
  }
}

class TotalsView extends ConsumerStatefulWidget {
  const TotalsView({required this.id, super.key});
  final String id;
  @override
  ConsumerState<TotalsView> createState() => _TotalsViewState();
}

class _TotalsViewState extends ConsumerState<TotalsView> {
  bool _today = false, _force = false;
  SnapshotDetail? _data;
  Future<SnapshotValuation>? _future;
  String get id => widget.id;
  @override
  void didUpdateWidget(covariant TotalsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != id) {
      _today = false;
      _future = null;
      _data = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(snapshotProvider(id));
    return detail.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => AppMessage(friendlyError(e)),
      data: (data) {
        if (_future == null || !identical(_data, data)) {
          _data = data;
          final today = _today, force = _force;
          _force = false;
          _future = ref
              .read(repositoryProvider.future)
              .then(
                (r) => r.valuation(
                  id,
                  today: today,
                  force: force,
                  draftPreview: true,
                ),
              );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('По курсу слепка')),
                ButtonSegment(value: true, label: Text('По сегодняшнему')),
              ],
              selected: {_today},
              onSelectionChanged: (selection) => setState(() {
                _today = selection.single;
                _future = null;
              }),
            ),
            if (_today)
              TextButton(
                onPressed: () => setState(() {
                  _force = true;
                  _future = null;
                }),
                child: const Text('Обновить сегодняшние курсы'),
              ),
            FutureBuilder<SnapshotValuation>(
              future: _future,
              builder: (context, state) {
                if (state.hasError) {
                  return AppMessage(friendlyError(state.error!));
                }
                if (!state.hasData) return const LinearProgressIndicator();
                final totals = state.data!.totals;
                final draft = data.header.text('status') == 'draft';
                Widget block(
                  String label,
                  Iterable<(String, AmountTotals, int, Color?)> rows,
                ) {
                  final shown = rows
                      .where((row) => draft || row.$2.total != Decimal.zero)
                      .toList();
                  if (shown.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: ExpansionTile(
                      title: Text(label),
                      children: [
                        for (final (name, value, precision, color) in shown)
                          _TotalRow(
                            name,
                            value,
                            precision: precision,
                            color: color,
                          ),
                      ],
                    ),
                  );
                }

                final overview = ref.watch(overviewProvider).value;
                final colors = {
                  for (final item
                      in overview?.liquidity ?? const <FinanceRecord>[])
                    item.id: Color(item.number('color')),
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Итоги',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _TotalRow('Всего, ₽', totals.rubles),
                    if (_today)
                      for (final quote in state.data!.rates)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${quote.code} ${amountsHidden(ref) ? '•••' : exactMoney(quote.value)} ₽ · ${compactRateSource(quote.source)}',
                          ),
                          trailing: _RateInfo(
                            'Действует / наблюдение: ${displayDateTime(quote.effectiveAt)}\nПолучен: ${displayDateTime(quote.fetchedAt.toIso8601String())}${quote.cached ? ' · кэш' : ''}',
                          ),
                        ),
                    block('По местам', [
                      for (final entry in totals.byStorageRubles.entries)
                        (
                          data.lines
                              .firstWhere(
                                (line) => line.text('storage_id') == entry.key,
                              )
                              .text('storage_name'),
                          entry.value,
                          2,
                          null,
                        ),
                    ]),
                    block('По валютам', [
                      for (final entry in totals.byCurrency.entries)
                        (
                          entry.key,
                          entry.value,
                          _currencyPrecision(data, entry.key),
                          null,
                        ),
                    ]),
                    block('По ликвидности', [
                      for (final entry in totals.byLiquidityRubles.entries)
                        (
                          data.lines
                              .firstWhere(
                                (line) =>
                                    line.text('liquidity_id') == entry.key,
                              )
                              .text('liquidity_name'),
                          entry.value,
                          2,
                          colors[entry.key],
                        ),
                    ]),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

int _currencyPrecision(SnapshotDetail detail, String code) {
  final line = detail.lines.firstWhere((line) => line.text('code') == code);
  return currencyDisplayPrecision(line.text('kind'), line.number('precision'));
}

class _RateInfo extends StatelessWidget {
  const _RateInfo(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Сведения о курсе',
    icon: const Icon(Icons.info_outline),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Сведения о курсе'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    ),
  );
}

class _TotalRow extends ConsumerWidget {
  const _TotalRow(this.label, this.value, {this.precision = 2, this.color});
  final String label;
  final AmountTotals value;
  final int precision;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amounts = [
      value.total,
      value.family,
      value.personal,
    ].map((amount) => visibleMoney(ref, amount, precision: precision)).toList();
    final theme = Theme.of(context);
    final numbers = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: [const FontFeature.tabularFigures()],
    );
    Widget cell(String title, String amount) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: theme.textTheme.labelSmall),
        Text(amount, style: numbers, textAlign: TextAlign.end),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (color != null)
              Padding(
                padding: const EdgeInsets.only(right: 5, top: 4),
                child: Icon(Icons.circle, size: 9, color: color),
              ),
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            if (constraints.maxWidth >= 540) ...[
              for (final (i, title) in ['Всего', 'Семейные', 'Личные'].indexed)
                Expanded(child: cell(title, amounts[i])),
            ] else
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    cell('Всего', amounts[0]),
                    Text(
                      'сем. ${amounts[1]} · лич. ${amounts[2]}',
                      textAlign: TextAlign.end,
                      style: numbers?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});
  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings> {
  bool _enabled = false, _protected = true, _loaded = false;
  String? _loadError;
  int _minutes = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(secretStoreProvider);
      final enabled = await store.read('biometric_enabled') == 'true';
      final protected = await store.read('screen_protected') != 'false';
      final minutes =
          int.tryParse(await store.read('lock_minutes') ?? '1') ?? 1;
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _protected = protected;
          _minutes = minutes;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Защищённое хранилище настроек недоступно');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loadError != null) AppMessage(_loadError!),
      SwitchListTile(
        title: const Text('Вход по отпечатку / Windows Hello'),
        value: _enabled,
        onChanged: !_loaded
            ? null
            : (value) async {
                try {
                  if (value) {
                    final auth = ref.read(deviceAuthProvider);
                    if (!await auth.available() || !await auth.authenticate()) {
                      throw StateError(
                        'Биометрия / Windows Hello недоступны или вход отменён',
                      );
                    }
                  }
                  await ref
                      .read(secretStoreProvider)
                      .write('biometric_enabled', value.toString());
                  if (mounted) setState(() => _enabled = value);
                } catch (e) {
                  if (context.mounted) {
                    AppMessage.show(context, friendlyError(e));
                  }
                }
              },
      ),
      if (Platform.isAndroid)
        SwitchListTile(
          title: const Text('Запрет скриншотов и превью'),
          value: _protected,
          onChanged: !_loaded
              ? null
              : (value) async {
                  try {
                    await const MethodChannel('delta/security')
                        .invokeMethod<void>('setProtected', value);
                    await ref
                        .read(secretStoreProvider)
                        .write('screen_protected', value.toString());
                    if (mounted) setState(() => _protected = value);
                  } catch (_) {
                    try {
                      await const MethodChannel('delta/security')
                          .invokeMethod<void>('setProtected', true);
                    } catch (_) {
                      /* Отказ платформы показан ниже. */
                    }
                    if (mounted) setState(() => _protected = true);
                    if (context.mounted) {
                      AppMessage.show(
                        context,
                        'Не удалось изменить защиту экрана',
                      );
                    }
                  }
                },
        ),
      DropdownButtonFormField<int>(
        key: ValueKey(_minutes),
        initialValue: _minutes,
        decoration: const InputDecoration(
          labelText: 'Блокировка после ухода в фон',
        ),
        items: [
          for (final value in [1, 2, 5, 10])
            DropdownMenuItem(value: value, child: Text('$value мин.')),
        ],
        onChanged: !_loaded
            ? null
            : (value) async {
                if (value != null) {
                  try {
                    await ref
                        .read(secretStoreProvider)
                        .write('lock_minutes', value.toString());
                    if (mounted) setState(() => _minutes = value);
                  } catch (_) {
                    if (context.mounted) {
                      AppMessage.show(
                        context,
                        'Не удалось сохранить время блокировки',
                      );
                    }
                  }
                }
              },
      ),
    ],
  );
}

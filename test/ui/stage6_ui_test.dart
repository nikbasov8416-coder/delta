import 'dart:io';
import 'dart:ui' as ui;

import 'package:delta/data/default_catalog.dart';
import 'package:delta/ui/delta_theme.dart';
import 'package:delta/ui/file_dialogs.dart';
import 'package:delta/ui/messages.dart';
import 'package:delta/ui/navigation/app_router.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/theme_settings.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';

Future<void> prepareFont() async {
  for (final (family, file) in [
    ('Preview', 'Roboto-Regular.ttf'),
    ('MaterialIcons', ''),
  ]) {
    final path = file.isEmpty
        ? '../tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        : '../tools/flutter/engine/src/flutter/txt/third_party/fonts/$file';
    final font = FontLoader(family)
      ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
    await font.load();
  }
}

void main() {
  const capture = bool.fromEnvironment('DELTA_CAPTURE_UI');
  const captureDraft = bool.fromEnvironment('DELTA_CAPTURE_DRAFT');
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Экраны Delta, ${width.toInt()} dp, ${brightness.name}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 920));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final draftPreview = captureDraft && brightness == Brightness.light;
        if (capture || draftPreview) await tester.runAsync(prepareFont);
        final repo = await testRepository();
        addTearDown(repo.close);
        final catalog = await repo.overview();
        final rub = catalog.currencies
            .singleWhere((record) => record.text('code') == 'RUB')
            .id;
        final btc = catalog.currencies
            .singleWhere((record) => record.text('code') == 'BTC')
            .id;
        final usd = catalog.currencies
            .singleWhere((row) => row.text('code') == 'USD')
            .id;
        for (final (i, name) in [
          'Копилка',
          'Вклад',
          'Кошелёк',
          'Пробный портфель',
          'Полис',
          'Нулевое место',
        ].indexed) {
          await repo.saveStorage(
            name: name,
            type: 'cash',
            liquidityId: catalog.liquidity[i % catalog.liquidity.length].id,
            organization: '',
            note: '',
            archived: false,
            currencyIds: [i == 2 ? btc : rub, if (i == 0) usd],
          );
        }
        for (final (i, date) in [
          '2026-08-06',
          '2026-09-15',
          '2026-10-17',
          '2026-11-17',
          '2026-11-17',
        ].indexed) {
          final id = await repo.createSnapshot(
            date,
            i == 4 ? 'Учебный слепок' : '',
          );
          for (final line in (await repo.snapshot(id)).lines) {
            final amount = switch (line.text('storage_name')) {
              'Копилка' =>
                line.text('code') == 'USD'
                    ? '0'
                    : i == 3
                    ? '950000.74'
                    : '${350000 + i * 38000}.74',
              'Вклад' => '${680000 + i * 98000}.44',
              'Пробный портфель' => '175000',
              'Полис' => '125000',
              'Кошелёк' => '0.41234567',
              _ => '0',
            };
            final family = line.text('code') == 'BTC'
                ? '0.1'
                : ['0', '125000', '175000'].contains(amount)
                ? '0'
                : '130000';
            await repo.saveLine(line.id, amount, family, '');
          }
          await repo.saveRate(id, btc, '6500000');
          await repo.saveRate(id, usd, '92.15');
          await repo.finalizeSnapshot(id);
        }
        final key = GlobalKey();
        final theme = deltaTheme(brightness);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWith((ref) async => repo),
              applicationVersionProvider.overrideWith(
                (ref) async => 'Версия 0.1.0 (сборка 17)',
              ),
              secretStoreProvider.overrideWithValue(
                MemorySecrets()
                  ..values[ThemeSettingsController.storageKey] =
                      brightness.name,
              ),
            ],
            child: Consumer(
              builder: (context, ref, child) => RepaintBoundary(
                key: key,
                child: MaterialApp.router(
                  routerConfig: ref.watch(appRouterProvider),
                  debugShowCheckedModeBanner: false,
                  theme: capture || draftPreview
                      ? theme.copyWith(
                          textTheme: theme.textTheme.apply(
                            fontFamily: 'Preview',
                          ),
                        )
                      : theme,
                  locale: const Locale('ru'),
                  supportedLocales: const [Locale('ru')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(width < 600 ? NavigationBar : NavigationRail),
          findsOneWidget,
        );
        expect(find.byType(Drawer), findsNothing);
        expect(find.text('Итого'), findsOneWidget);
        expect(find.text('Нулевое место'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Consumer)),
        );
        final router = container.read(appRouterProvider);
        Future<void> save(String page, {bool enabled = capture}) async {
          expect(tester.takeException(), isNull);
          if (!enabled) return;
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final file = File(
              '../tmp/delta-ui/$page-${width.toInt()}-${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
          });
        }

        await save('home');
        await tester.tap(find.byTooltip('Скрыть суммы'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('−7,1 % (••• ₽) с прошлого слепка'),
          findsOneWidget,
        );
        expect(find.textContaining('4\u00a0554\u00a0248,04'), findsNothing);
        await tester.tap(find.byTooltip('Показать суммы'));
        await tester.pumpAndSettle();
        router.go('/snapshots');
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ListTile, 'Зафиксирован · Учебный слепок'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Учебный слепок'), findsOneWidget);
        expect(find.text('Зафиксирован'), findsOneWidget);
        expect(find.textContaining('Мест нет в черновике'), findsNothing);
        expect(find.text('Добавить место'), findsNothing);
        expect(find.text('Удалить черновик'), findsNothing);
        expect(find.text('Нулевое место'), findsNothing);
        expect(find.text('USD: 0,00'), findsNothing);
        expect(find.textContaining('RUB: 502'), findsOneWidget);
        final back = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(BackButton),
        );
        expect(back, findsOneWidget);
        await save('snapshot');
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Слепки'), findsOneWidget);
        router.go('/reports');
        await tester.pumpAndSettle();
        await save('reports');
        final millions = find.text('1\u00a0млн');
        expect(millions, findsWidgets);
        expect(tester.widget<Text>(millions.first).softWrap, isFalse);
        final navigation = find.byType(
          width < 600 ? NavigationBar : NavigationRail,
        );
        await tester.tap(
          find.descendant(of: navigation, matching: find.text('Ещё')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Версия 0.1.0 (сборка 17)'), findsOneWidget);
        for (final page in [
          'Места хранения',
          'Справочники',
          'Настройки',
          'Резервная копия',
          'Экспорт в Excel',
        ]) {
          await tester.tap(find.widgetWithText(ListTile, page));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(AppBar, page), findsOneWidget);
          if (page == 'Настройки') {
            expect(find.text('Оформление'), findsOneWidget);
            final theme = tester.widget<DropdownButton<ThemeMode>>(
              find.byType(DropdownButton<ThemeMode>),
            );
            expect(
              theme.value,
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            );
            await save('settings');
          }
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(AppBar, 'Ещё'), findsOneWidget);
        }
        final draft = await repo.createSnapshot(
          '2026-11-18',
          'Учебный черновик',
        );
        await repo.saveRate(draft, btc, '6500000');
        await repo.saveRate(draft, usd, '92.15');
        await repo.saveStorage(
          name: 'Архивное место',
          type: 'cash',
          liquidityId: catalog.liquidity.first.id,
          organization: '',
          note: '',
          archived: true,
          currencyIds: [rub],
        );
        router.go('/snapshots/$draft');
        await tester.pumpAndSettle();
        expect(find.textContaining('Мест нет в черновике'), findsNothing);
        router.go('/storage');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Добавить место хранения'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Новый конверт');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final rubChoice = find.widgetWithText(CheckboxListTile, 'RUB');
        await Scrollable.ensureVisible(
          tester.element(rubChoice),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(rubChoice);
        await tester.pump();
        expect(tester.widget<CheckboxListTile>(rubChoice).value, isTrue);
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        router.go('/snapshots/$draft');
        await tester.pumpAndSettle();
        expect(find.text('Черновик'), findsOneWidget);
        expect(find.text('Добавить место'), findsOneWidget);
        expect(find.text('Удалить черновик'), findsOneWidget);
        final warning = find.widgetWithText(
          AppMessage,
          'Мест нет в черновике: 1',
        );
        expect(warning, findsOneWidget);
        await save('draft', enabled: draftPreview);
        await tester.tap(
          find.descendant(of: warning, matching: find.text('Добавить')),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AlertDialog, 'Добавить место'),
          findsOneWidget,
        );
        expect(find.text('Новый конверт'), findsOneWidget);
        expect(find.text('Архивное место'), findsNothing);
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        final add = find.widgetWithText(TextButton, 'Добавить место');
        expect(tester.widget<TextButton>(add).onPressed, isNull);
        expect(
          (await repo.snapshot(draft)).lines
              .any((row) => row.text('storage_name') == 'Новый конверт'),
          isTrue,
        );
        await tester.scrollUntilVisible(find.text('USD: 0,00'), 160);
        expect(find.text('USD: 0,00'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('По местам'), 300);
        await Scrollable.ensureVisible(
          tester.element(find.text('По местам')),
          alignment: .4,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('По местам'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.widgetWithText(ExpansionTile, 'По местам'),
            matching: find.text('Нулевое место'),
          ),
          findsOneWidget,
        );
        container.invalidate(overviewProvider);
        router.go('/');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Есть незавершённый слепок от 18.11'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Продолжить'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Слепок'), findsOneWidget);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Главная'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Продолжить'));
        await tester.pumpAndSettle();
        final delete = find.widgetWithText(TextButton, 'Удалить черновик');
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(find.text('Удалить черновик от 18.11.2026?'), findsOneWidget);
        expect(find.text('Введённые в нём суммы пропадут'), findsOneWidget);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(find.text('Учебный черновик'), findsOneWidget);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Слепки'), findsOneWidget);
        expect(find.textContaining('Учебный черновик'), findsNothing);
        router.go('/');
        await tester.pumpAndSettle();
        expect(find.textContaining('Есть незавершённый слепок'), findsNothing);
      });
    }
  }

  test('Цвета ликвидности контрастируют с фоном в обеих темах', () {
    expect(liquidityColors.length, 5);
    for (final key in liquidityColors.keys) {
      final color = Color(key);
      expect(color, isNot(anyOf(familyColor, personalColor)));
      for (final brightness in Brightness.values) {
        final surface = deltaTheme(brightness).colorScheme.surface;
        final a = color.computeLuminance(), b = surface.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(
          contrast,
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}: $color',
        );
      }
    }
  });

  test('Контраст текста и кнопок выдерживает WCAG AA в обеих темах', () {
    double contrast(Color a, Color b) {
      final left = a.computeLuminance(), right = b.computeLuminance();
      return left > right
          ? (left + .05) / (right + .05)
          : (right + .05) / (left + .05);
    }

    for (final brightness in Brightness.values) {
      final color = deltaTheme(brightness).colorScheme;
      for (final (foreground, background) in [
        (color.onSurface, color.surface),
        (color.onSurface, color.surfaceContainerLow),
        (color.onPrimary, color.primary),
        (color.onPrimaryContainer, color.primaryContainer),
        (color.onErrorContainer, color.errorContainer),
        (color.error, color.primaryContainer),
      ]) {
        expect(
          contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '${brightness.name}: $foreground на $background',
        );
      }
    }
  });

  testWidgets('Общие плашки ошибок, предупреждений и успеха', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const AppMessage('Ошибка'),
                const AppMessage('Предупреждение', kind: MessageKind.warning),
                TextButton(
                  onPressed: () => AppMessage.show(
                    context,
                    'Готово',
                    kind: MessageKind.success,
                  ),
                  child: const Text('Проверить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    final text = tester.widget<Text>(find.text('Ошибка'));
    final context = tester.element(find.text('Ошибка'));
    expect(text.style!.color, Theme.of(context).colorScheme.onErrorContainer);
    expect(text.style!.fontWeight, FontWeight.bold);
    await tester.tap(find.text('Проверить'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

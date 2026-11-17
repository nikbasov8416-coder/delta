import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:delta/data/finance_repository.dart';
import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/ui/providers.dart';
import 'package:delta/ui/sync/sync_lifecycle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_database.dart';
import '../sync/fake_disk.dart';

class ExitSync extends SyncService {
  ExitSync(DriftFinanceRepository repo)
    : super(repo, MemorySecrets(), diskFactory: (_) => FakeDisk());
  bool pending = true;
  int checks = 0, exchanges = 0;
  final completion = Completer<void>();
  @override
  bool get enabled => true;
  @override
  Future<bool> refreshPending() async {
    checks++;
    return pending;
  }

  @override
  Future<void> synchronize({bool uploadOnly = false}) {
    exchanges++;
    return completion.future;
  }
}

void main() {
  for (final scenario in [
    'успех',
    'ошибка',
    'тайм-аут',
    'заблокировано',
    'пусто',
  ]) {
    testWidgets('Windows-перехват закрытия на любой ОС: $scenario', (
      tester,
    ) async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final service = ExitSync(repo)..pending = scenario != 'пусто';
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncLifecycleWindowsProvider.overrideWithValue(true),
            syncServiceProvider.overrideWith((ref) async => service),
          ],
          child: const MaterialApp(
            home: SyncLifecycle(child: Scaffold(body: Text('Окно'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SyncLifecycle)),
      );
      container
          .read(sessionAccessProvider.notifier)
          .setUnlocked(scenario != 'заблокировано');
      AppExitResponse? response;
      final exit = tester.binding.handleRequestAppExit().then(
        (value) => response = value,
      );
      await tester.pump();
      if (scenario == 'заблокировано' || scenario == 'пусто') {
        expect(response, AppExitResponse.exit);
        expect(service.exchanges, 0);
        expect(service.checks, scenario == 'пусто' ? 1 : 0);
        expect(find.text('Синхронизация… приложение закроется'), findsNothing);
      } else {
        expect(response, isNull); // Ответ действительно задержан слушателем.
        expect(service.exchanges, 1);
        expect(
          find.text('Синхронизация… приложение закроется'),
          findsOneWidget,
        );
        if (scenario == 'тайм-аут') {
          await tester.pump(const Duration(seconds: 14));
          expect(response, isNull);
          await tester.pump(const Duration(seconds: 1));
        } else {
          if (scenario == 'ошибка') {
            service.completion.completeError(StateError('Выдуманный сбой'));
          } else {
            service.completion.complete();
          }
          await tester.pump();
        }
        expect(response, AppExitResponse.exit);
      }
      await exit;
      await tester.pumpWidget(const SizedBox.shrink());
      // После dispose перехват снят, повторный запрос не запускает обмен.
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(
        service.exchanges,
        scenario == 'заблокировано' || scenario == 'пусто' ? 0 : 1,
      );
    });
  }
}

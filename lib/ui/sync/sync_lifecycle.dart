import 'package:material_ui/material_ui.dart';

import 'dart:io';

import 'dart:ui' show AppExitResponse;

import 'exit_sync.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Существует только после разблокировки приложения.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  AppLifecycleListener? _exitListener;
  bool _exiting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      _exitListener = AppLifecycleListener(
        onExitRequested: () async {
          final service = ref.read(syncServiceProvider).asData?.value;
          await exchangeBeforeExit(
            unlocked: ref.read(sessionAccessProvider),
            needed: () async =>
                service != null &&
                service.enabled &&
                (service.busy || await service.refreshPending()),
            exchange: () async {
              await service?.synchronize();
            },
            showWaiting: () {
              if (mounted) setState(() => _exiting = true);
            },
          );
          return AppExitResponse.exit;
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(sessionAccessProvider)) {
      ref.read(syncServiceProvider).asData?.value?.schedule();
    } else if (Platform.isAndroid &&
        [AppLifecycleState.paused, AppLifecycleState.hidden].contains(state) &&
        ref.read(sessionAccessProvider)) {
      ref.read(syncServiceProvider).asData?.value?.sendPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    return Stack(
      children: [
        widget.child,
        if (_exiting)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xdd000000),
              child: Center(
                child: Text(
                  'Синхронизация… приложение закроется',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _exitListener?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

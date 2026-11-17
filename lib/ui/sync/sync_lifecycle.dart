import 'package:flutter/widgets.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(sessionAccessProvider)) {
      ref.read(syncServiceProvider).asData?.value?.schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

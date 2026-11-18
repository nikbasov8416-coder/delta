import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/app.dart';
import 'ui/theme_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(themePreferenceProvider.future);
  runApp(
    UncontrolledProviderScope(container: container, child: const DeltaApp()),
  );
}

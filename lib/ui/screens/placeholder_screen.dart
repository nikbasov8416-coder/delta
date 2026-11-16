import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';

/// На этапе 1 нет ввода, сохранения финансовых данных или сетевых запросов.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Delta · $title')),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(child: Text('Delta')),
            for (final entry in appScreens.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(entry.key);
                },
              ),
          ],
        ),
      ),
    ),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Каркас приложения. Работа с данными появится на следующих этапах.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

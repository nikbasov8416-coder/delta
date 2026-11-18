import 'package:material_ui/material_ui.dart';

enum MessageKind { error, warning, success }

class AppMessage extends StatelessWidget {
  const AppMessage(
    this.text, {
    this.kind = MessageKind.error,
    this.action,
    super.key,
  });

  final String text;
  final MessageKind kind;
  final Widget? action;

  static void show(
    BuildContext context,
    String text, {
    MessageKind kind = MessageKind.error,
  }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppMessage(text, kind: kind)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground, icon) = switch (kind) {
      MessageKind.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.warning_amber_rounded,
      ),
      MessageKind.warning => (
        const Color(0xffffedac),
        const Color(0xff352900),
        Icons.warning_amber_rounded,
      ),
      MessageKind.success => (
        colors.inverseSurface,
        colors.onInverseSurface,
        Icons.check,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

ButtonStyle destructiveStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
  );
}

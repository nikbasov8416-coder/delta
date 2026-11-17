import 'package:delta/ui/sync/sync_help.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Справка объясняет подключение по шагам без технических слов', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SyncHelp()));
    expect(find.text('Редкие ситуации'), findsOneWidget);
    final text = SyncHelp.sections.values.join('\n');
    expect(text, contains('Получение и отправка изменений'));
    expect(text, isNot(contains('Полный обмен')));
    expect(text, isNot(contains('набор')));
    expect(text, isNot(contains('шифротекст')));
    expect(text, contains('зашифрованные данные'));
    final steps = SyncHelp.sections['Новый телефон, ПК или переустановка']!;
    var previous = -1;
    for (final step in [
      'Установите Delta',
      'Настройки',
      'синхронизация',
      '«Подключиться»',
      '«Войти через Яндекс»',
      'Скопируйте ссылку',
      'в браузере',
      'разрешите доступ',
      'вставьте токен',
      'введите общую парольную фразу',
      '«заменить данными с Диска»',
    ]) {
      final index = steps.indexOf(step);
      expect(index, greaterThan(previous), reason: step);
      previous = index;
    }
    expect(
      text,
      contains(
        'Без рабочего устройства и без фразы данные с Диска не восстановить',
      ),
    );
    expect(text, contains('очередь ваших изменений сохранится'));
    expect(text, contains('обновите её на всех устройствах'));
  });
}

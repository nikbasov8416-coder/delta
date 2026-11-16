import 'package:delta/ui/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Прямое чтение репозитория без входа не вызывает платформенное открытие',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await expectLater(
        container.read(repositoryProvider.future),
        throwsStateError,
      );
      expect(container.read(sessionAccessProvider), isFalse);
    },
  );
}

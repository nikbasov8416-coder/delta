import 'dart:convert';

import 'package:delta/domain/security/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  test('PIN: только соль/хеш, случайная соль и корректная проверка', () async {
    final first = MemorySecrets(), second = MemorySecrets();
    final a = PinService(read: first.read, write: first.write),
        b = PinService(read: second.read, write: second.write);
    await expectLater(a.create('123'), throwsFormatException);
    await a.create('135790');
    await b.create('135790');
    expect(first.values['pin_v1'], isNot(contains('135790')));
    expect(
      jsonDecode(first.values['pin_v1']!)['salt'],
      isNot(jsonDecode(second.values['pin_v1']!)['salt']),
    );
    expect(await a.verify('135790'), isTrue);
    expect(await a.verify('135791'), isFalse);
    await expectLater(a.create('246802'), throwsStateError);
  });
  test(
    'Задержка после пяти ошибок сохраняется между открытиями и растёт',
    () async {
      var now = DateTime.utc(2026, 1, 1);
      final store = MemorySecrets();
      PinService service() =>
          PinService(read: store.read, write: store.write, now: () => now);
      await service().create('135790');
      for (var i = 0; i < 5; i++) {
        expect(await service().verify('000000'), isFalse);
      }
      expect(await service().delay(), const Duration(seconds: 30));
      expect(await service().verify('135790'), isFalse);
      now = now.add(const Duration(seconds: 31));
      expect(await service().verify('000000'), isFalse);
      expect(await service().delay(), const Duration(seconds: 60));
      now = now.add(const Duration(seconds: 61));
      expect(await service().verify('135790'), isTrue);
      expect(await service().delay(), Duration.zero);
    },
  );
}

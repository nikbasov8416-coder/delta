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
  test(
    'Смена числа итераций вверх и вниз мигрирует хеш только при правильном PIN',
    () async {
      final store = MemorySecrets();
      PinService service(int count) => PinService(
        read: store.read,
        write: store.write,
        targetIterations: count,
      );
      await service(1000).create('135790');
      final first = store.values['pin_v1'];
      expect(await service(2000).verify('000000'), isFalse);
      expect(store.values['pin_v1'], first);
      expect(await service(2000).verify('135790'), isTrue);
      expect(jsonDecode(store.values['pin_v1']!)['iterations'], 2000);
      expect(
        jsonDecode(store.values['pin_v1']!)['salt'],
        isNot(jsonDecode(first!)['salt']),
      );
      expect(await service(1500).verify('135790'), isTrue);
      expect(jsonDecode(store.values['pin_v1']!)['iterations'], 1500);
      expect(await service(1500).verify('135790'), isTrue);
    },
  );
  test('Ошибка записи миграции оставляет прежний PIN-хеш пригодным', () async {
    final store = MemorySecrets();
    final first = PinService(
      read: store.read,
      write: store.write,
      targetIterations: 1000,
    );
    await first.create('135790');
    final saved = store.values['pin_v1'];
    final failing = PinService(
      read: store.read,
      targetIterations: 2000,
      write: (key, value) async {
        if (key == 'pin_v1') throw StateError('Синтетическая ошибка записи');
        await store.write(key, value);
      },
    );
    expect(await failing.verify('135790'), isTrue);
    expect(failing.migrationPending, isTrue);
    expect(store.values['pin_v1'], saved);
    expect(await first.verify('135790'), isTrue);
  });
  test(
    'Прерванная перезапись основного слота восстанавливается из второй копии',
    () async {
      final store = MemorySecrets();
      final original = PinService(
        read: store.read,
        write: store.write,
        targetIterations: 1000,
      );
      await original.create('135790');
      final interrupted = PinService(
        read: store.read,
        targetIterations: 2000,
        write: (key, value) async {
          if (key == 'pin_v1') {
            store.values[key] = '{broken';
            throw StateError('Синтетическая неполная запись');
          }
          await store.write(key, value);
        },
      );
      expect(await interrupted.verify('135790'), isTrue);
      final restored = PinService(
        read: store.read,
        write: store.write,
        targetIterations: 2000,
      );
      expect(await restored.configured, isTrue);
      expect(await restored.verify('135790'), isTrue);
      expect(jsonDecode(store.values['pin_v1']!)['iterations'], 2000);
      expect(store.values['pin_v1'], store.values['pin_v2']);
    },
  );
  test('Прерванная запись нового слота не затрагивает прежний PIN', () async {
    final store = MemorySecrets();
    await PinService(
      read: store.read,
      write: store.write,
      targetIterations: 1000,
    ).create('135790');
    final saved = store.values['pin_v1'];
    final failing = PinService(
      read: store.read,
      targetIterations: 2000,
      write: (key, value) async {
        if (key == 'pin_v2') {
          store.values[key] = '{broken';
          throw StateError('Синтетическая неполная запись');
        }
        await store.write(key, value);
      },
    );
    expect(await failing.verify('135790'), isTrue);
    expect(store.values['pin_v1'], saved);
    final repaired = PinService(
      read: store.read,
      write: store.write,
      targetIterations: 2000,
    );
    expect(await repaired.verify('135790'), isTrue);
    expect(store.values['pin_v1'], store.values['pin_v2']);
  });
  test(
    'Первый PIN не считается сохранённым, если чтение не подтверждает запись',
    () async {
      final store = MemorySecrets();
      final service = PinService(
        read: store.read,
        targetIterations: 1000,
        write: (key, value) async {
          await store.write(key, key == 'pin_v1' ? '{broken' : value);
        },
      );
      await expectLater(service.create('135790'), throwsStateError);
      expect(store.values.containsKey('pin_v2'), isFalse);
    },
  );
}

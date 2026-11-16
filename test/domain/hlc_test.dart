import 'package:delta/domain/sync/hlc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'HLC монотонны при одинаковом времени, откате и после восстановления',
    () {
      var now = 1000;
      final clock = HybridClock('device', milliseconds: () => now);
      final a = clock.next(), b = clock.next();
      expect(b.compareTo(a), greaterThan(0));
      now = 1;
      final c = clock.next();
      expect(c.compareTo(b), greaterThan(0));
      final restarted = HybridClock('device', milliseconds: () => now);
      restarted.observe(c);
      expect(restarted.next().compareTo(c), greaterThan(0));
    },
  );
}

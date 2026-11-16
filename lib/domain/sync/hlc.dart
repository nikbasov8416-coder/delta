/// Лексикографически сравнимые гибридные часы, устойчивые к откату часов ОС.
class HybridClock {
  HybridClock(this.deviceId, {int Function()? milliseconds})
    : _milliseconds =
          milliseconds ?? (() => DateTime.now().millisecondsSinceEpoch);
  final String deviceId;
  final int Function() _milliseconds;
  int _wall = 0;
  int _counter = 0;

  void observe(String timestamp) {
    final parts = timestamp.split(':');
    final wall = int.parse(parts[0]);
    final counter = int.parse(parts[1]);
    if (wall > _wall || (wall == _wall && counter > _counter)) {
      _wall = wall;
      _counter = counter;
    }
  }

  String next() {
    final now = _milliseconds();
    if (now > _wall) {
      _wall = now;
      _counter = 0;
    } else {
      _counter++;
    }
    return '${_wall.toString().padLeft(13, '0')}:${_counter.toString().padLeft(10, '0')}:$deviceId';
  }
}

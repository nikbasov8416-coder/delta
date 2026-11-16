/// Меняется после замера владельцем на телефоне. Старые хеши читаются со
/// своими параметрами и обновляются только после успешного ввода PIN.
abstract final class PinPolicy {
  static const iterations = 310000;
  static const minimumAcceptedIterations = 1000;
  static const maximumAcceptedIterations = 2000000;
}

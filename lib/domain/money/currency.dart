/// Валюта и допустимая точность суммы. Курсы имеют свою точность.
final class Currency {
  Currency(this.code, this.precision) {
    if (!RegExp(r'^[A-Z]{3,8}$').hasMatch(code) ||
        precision < 0 ||
        precision > 18) {
      throw ArgumentError('Некорректная валюта или точность');
    }
  }

  final String code;
  final int precision;
}

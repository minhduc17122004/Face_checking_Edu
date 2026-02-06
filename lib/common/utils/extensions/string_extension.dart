import 'package:diacritic/diacritic.dart';

extension NumX on num {
  String toCurrencyFormat({String? currencyName, int? decimalDigits}) {
    return '${this < 0 ? '-' : ''}\$${abs().toStringAsFixed(decimalDigits ?? 2)}';
  }
}

extension StringX on String {
  String removeVietnameseDiacritics() {
    return removeDiacritics(toLowerCase());
  }
}

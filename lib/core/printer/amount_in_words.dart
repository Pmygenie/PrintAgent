/// Indian-numbering amount in words for A4 bills only.
class AmountInWords {
  AmountInWords._();

  static const _ones = [
    '',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];

  static const _tens = [
    '',
    '',
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'sixty',
    'seventy',
    'eighty',
    'ninety',
  ];

  /// `481` → `Rupees four hundred eighty-one only`
  static String rupees(double amount) {
    if (amount < 0) amount = 0;
    final rupees = amount.floor();
    var paise = ((amount - rupees) * 100).round();
    if (paise >= 100) {
      paise = 0;
    }
    final rupeeWords = rupees == 0 ? 'zero' : _indian(rupees);
    if (paise > 0) {
      return 'Rupees $rupeeWords and ${_upTo99(paise)} paise only';
    }
    return 'Rupees $rupeeWords only';
  }

  static String _indian(int n) {
    if (n == 0) return 'zero';
    final parts = <String>[];
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final hundred = n ~/ 100;
    final rest = n % 100;

    if (crore > 0) parts.add('${_upTo99(crore)} crore');
    if (lakh > 0) parts.add('${_upTo99(lakh)} lakh');
    if (thousand > 0) parts.add('${_upTo99(thousand)} thousand');
    if (hundred > 0) parts.add('${_ones[hundred]} hundred');
    if (rest > 0) {
      final restWords = _upTo99(rest);
      if (parts.isNotEmpty) {
        parts.add('and $restWords');
      } else {
        parts.add(restWords);
      }
    }
    return parts.join(' ');
  }

  static String _upTo99(int n) {
    if (n < 20) return _ones[n];
    final ten = _tens[n ~/ 10];
    final one = _ones[n % 10];
    if (one.isEmpty) return ten;
    return '$ten-$one';
  }
}

String formatNaira(num amount) {
  final rounded = amount.toDouble();
  final isWholeNumber = rounded == rounded.roundToDouble();
  final fixedValue = rounded.toStringAsFixed(isWholeNumber ? 0 : 2);
  final parts = fixedValue.split('.');
  final wholePart = parts.first;
  final sign = wholePart.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? wholePart : wholePart.substring(1);
  final formattedWholePart = _groupThousands(digits);
  final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

  return '$sign₦$formattedWholePart$decimalPart';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);

    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}

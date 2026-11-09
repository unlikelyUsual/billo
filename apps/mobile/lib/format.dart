String formatSatang(int satang) {
  final negative = satang < 0;
  final abs = satang.abs();
  final baht = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final body = '${_group(baht)}.$frac';
  return negative ? '-฿$body' : '฿$body';
}

String formatBahtInput(int satang) {
  final abs = satang.abs();
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '${abs ~/ 100}.$frac';
}

int parseBahtToSatang(String raw) {
  final cleaned = raw.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
    throw const FormatException('invalid');
  }
  final parts = cleaned.split('.');
  final baht = int.parse(parts[0]);
  final frac = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return baht * 100 + frac;
}

String formatCivilDate(String iso, {required String locale}) {
  final parts = iso.split('-');
  if (parts.length != 3) {
    return iso;
  }
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const th = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  if (month < 1 || month > 12) {
    return iso;
  }
  if (locale == 'th') {
    return '$day ${th[month - 1]} ${year + 543}';
  }
  return '$day ${en[month - 1]} $year';
}

int daysFromToday(String due, String today) {
  return _dayNumber(due) - _dayNumber(today);
}

int _dayNumber(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]).millisecondsSinceEpoch ~/
      86400000;
}

String _group(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index += 1) {
    if (index > 0 && (text.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[index]);
  }
  return buffer.toString();
}

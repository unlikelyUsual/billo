import 'package:flutter_test/flutter_test.dart';

import 'package:billo/format.dart';

void main() {
  test('satang formats as baht without binary fractions', () {
    expect(formatSatang(9752350), '฿97,523.50');
    expect(formatSatang(100), '฿1.00');
    expect(formatSatang(50), '฿0.50');
    expect(formatSatang(0), '฿0.00');
  });

  test('baht text parses back to integer satang', () {
    expect(parseBahtToSatang('97,523.50'), 9752350);
    expect(parseBahtToSatang('15000.5'), 1500050);
    expect(parseBahtToSatang('12'), 1200);
    expect(() => parseBahtToSatang('1.234'), throwsFormatException);
    expect(() => parseBahtToSatang('1e5'), throwsFormatException);
  });

  test('civil dates stay on the Bangkok calendar day', () {
    expect(formatCivilDate('2026-11-08', locale: 'en'), '8 Nov 2026');
    expect(formatCivilDate('2026-11-08', locale: 'th'), '8 พ.ย. 2569');
    expect(daysFromToday('2026-11-09', '2026-11-08'), 1);
    expect(daysFromToday('2026-12-01', '2026-11-30'), 1);
    expect(daysFromToday('2026-11-07', '2026-11-08'), -1);
  });
}

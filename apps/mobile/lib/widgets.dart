import 'package:flutter/material.dart';

import 'format.dart';
import 'l10n.dart';
import 'models.dart';
import 'theme.dart';

class FoldMark extends StatelessWidget {
  const FoldMark({super.key, this.size = 28, this.color = BilloColors.cream});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _FoldPainter(color));
  }
}

class _FoldPainter extends CustomPainter {
  const _FoldPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final fold = size.width * 0.38;
    final page = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(page, paint);
    final ear = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold)
      ..close();
    canvas.drawPath(ear, Paint()..color = BilloColors.creamFold);
  }

  @override
  bool shouldRepaint(covariant _FoldPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('demo-banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E7E1),
        border: Border.all(color: BilloColors.stamp, width: 1.4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: BilloColors.stamp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.satang, {super.key, this.style});

  final int satang;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatSatang(satang),
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        color: BilloColors.slip,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PdfResultPanel extends StatelessWidget {
  const PdfResultPanel({
    super.key,
    required this.title,
    required this.message,
    required this.note,
  });

  final String title;
  final String message;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pdf-unavailable'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BilloColors.slip,
        border: Border.all(color: BilloColors.stamp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BilloColors.stamp,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(message),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class PaymentResultView extends StatelessWidget {
  const PaymentResultView({
    super.key,
    required this.payment,
    required this.l10n,
  });

  final PaymentModel payment;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.result, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.demoBanner,
            style: const TextStyle(
              color: BilloColors.stamp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in payment.items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BilloColors.slip,
                border: Border.all(color: BilloColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.issuer} · ${item.last4}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  MoneyText(item.amountSatang),
                  const SizedBox(height: 4),
                  Text(l10n.outcomeNote(item.status)),
                  if (item.status == 'pending') ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.noRetry,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color edgeFor(String bucket, String settlement) {
  if (settlement == 'payment_pending') return BilloColors.pending;
  if (settlement == 'payment_failed') return BilloColors.stamp;
  if (bucket == 'due_soon' || bucket == 'overdue') return BilloColors.stamp;
  return BilloColors.spine;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billo/app.dart';
import 'package:billo/l10n.dart';
import 'package:billo/models.dart';
import 'package:billo/widgets.dart';

import 'scripted_api.dart';

void main() {
  testWidgets('home shows the demo banner, balance, and selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(BilloApp(api: ScriptedApi()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.text('DEMO · No real money moves'), findsOneWidget);
    expect(find.text('฿97,523.50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('select_stmt_kbank_2026-10-25')));
    await tester.pump();
    expect(find.byKey(const Key('pay-bar')), findsOneWidget);
    expect(find.text('Review payment'), findsOneWidget);

    await tester.tap(find.byKey(const Key('locale-th')));
    await tester.pump();
    expect(find.text('เดโม · ไม่มีการเคลื่อนเงินจริง'), findsWidgets);
  });

  testWidgets('pending result says the payment will not be retried', (
    tester,
  ) async {
    const payment = PaymentModel(
      id: 'pay_1',
      createdAt: '2026-11-08T09:00:00+07:00',
      batchStatus: 'action_required',
      autoRetry: false,
      items: [
        PaymentItemModel(
          statementId: 'stmt_krungsri',
          issuer: 'krungsri',
          last4: '1190',
          amountSatang: 2334500,
          status: 'pending',
          outcomeMessage: 'pending',
        ),
        PaymentItemModel(
          statementId: 'stmt_bbl',
          issuer: 'bbl',
          last4: '2207',
          amountSatang: 890050,
          status: 'failed',
          outcomeMessage: 'failed',
        ),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentResultView(payment: payment, l10n: L10n('en')),
      ),
    );
    expect(find.text('Billo will not retry this payment.'), findsOneWidget);
    expect(find.textContaining('declined'), findsOneWidget);
  });

  testWidgets('unavailable PDF panel does not show an amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PdfResultPanel(
          title: 'Extraction unavailable',
          message: 'This PDF has no verified layout.',
          note: 'Amounts were not guessed.',
        ),
      ),
    );
    expect(find.byKey(const Key('pdf-unavailable')), findsOneWidget);
    expect(find.text('Amounts were not guessed.'), findsOneWidget);
    expect(find.textContaining('฿'), findsNothing);
  });
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'controller.dart';
import 'format.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    final home = controller.home;
    return Column(
      children: [
        FolderHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FoldMark(),
                  const SizedBox(width: 10),
                  const Text(
                    'Billo',
                    style: TextStyle(
                      color: BilloColors.cream,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const LocaleSwitch(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutPage(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.info_outline,
                      color: BilloColors.cream,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.household,
                style: const TextStyle(color: BilloColors.cream),
              ),
              if (home != null) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.openBalance,
                  style: const TextStyle(
                    color: BilloColors.cream,
                    letterSpacing: 0.6,
                  ),
                ),
                MoneyText(
                  home.totals.openFullDueSatang,
                  key: const Key('open-balance'),
                  style: const TextStyle(
                    color: BilloColors.cream,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${l10n.minimum} ${formatSatang(home.totals.openMinDueSatang)} · ${l10n.dueSoon} ${formatSatang(home.totals.dueSoonFullDueSatang)}',
                  style: const TextStyle(color: BilloColors.cream),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _body(context, controller)),
      ],
    );
  }

  Widget _body(BuildContext context, BilloController controller) {
    final l10n = controller.t;
    if (controller.loading && controller.home == null) {
      return Center(child: Text(l10n.loading));
    }
    if (controller.home == null) {
      return _Message(
        text: controller.errorMessage ?? l10n.apiDown,
        action: l10n.tryAgain,
        onPressed: controller.refresh,
      );
    }
    final home = controller.home!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        DemoBanner(text: l10n.demoBanner),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: controller.selectPayable,
              child: Text(l10n.selectPayable),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ImportPage()),
              ),
              child: Text(l10n.import),
            ),
            TextButton(
              onPressed: controller.clearSelection,
              child: Text(l10n.clear),
            ),
          ],
        ),
        if (home.bills.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(l10n.emptyBills),
          )
        else
          for (final bill in home.bills) _BillSlip(bill: bill),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              controller.errorMessage!,
              style: const TextStyle(color: BilloColors.stamp),
            ),
          ),
      ],
    );
  }
}

class _BillSlip extends StatelessWidget {
  const _BillSlip({required this.bill});

  final StatementModel bill;

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    final today = controller.home?.demo.today ?? bill.dueDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BilloColors.slip,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StatementPage(statement: bill),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: BilloColors.line),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    color: edgeFor(bill.dueBucket, bill.settlementState),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.issuerName(controller.localeCode),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${bill.network} · ${l10n.ending} ${bill.last4}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatCivilDate(bill.dueDate, locale: controller.localeCode)} · ${l10n.dueLabel(daysFromToday(bill.dueDate, today))}',
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              StatusPill(
                                label: l10n.reviewLabel(bill.reviewState),
                                color: BilloColors.inkSoft,
                              ),
                              StatusPill(
                                label: l10n.settlementLabel(
                                  bill.settlementState,
                                ),
                                color: edgeFor(
                                  bill.dueBucket,
                                  bill.settlementState,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MoneyText(
                          bill.fullDueSatang,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (bill.selectable)
                          Checkbox(
                            key: Key('select_${bill.id}'),
                            value: controller.selected.contains(bill.id),
                            onChanged: (_) => controller.toggle(bill.id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    return Column(
      children: [
        FolderHeader(
          child: Row(
            children: [
              const FoldMark(size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.yourCards,
                style: const TextStyle(
                  color: BilloColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.cards.isEmpty
              ? Center(
                  child: Text(controller.loading ? l10n.loading : l10n.apiDown),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DemoBanner(text: l10n.demoBanner, compact: true),
                    const SizedBox(height: 12),
                    for (final card in controller.cards)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BilloColors.slip,
                          border: Border.all(color: BilloColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.issuerName(controller.localeCode),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text('${card.network} · ${card.last4}'),
                                ],
                              ),
                            ),
                            MoneyText(
                              card.openFullDueSatang,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    return Column(
      children: [
        FolderHeader(
          child: Text(
            l10n.activity,
            style: const TextStyle(
              color: BilloColors.cream,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: controller.payments.isEmpty
              ? Center(
                  child: Text(
                    controller.loading ? l10n.loading : l10n.emptyActivity,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DemoBanner(text: l10n.demoBanner, compact: true),
                    const SizedBox(height: 12),
                    for (final payment in controller.payments)
                      ListTile(
                        tileColor: BilloColors.slip,
                        title: Text(payment.batchStatus),
                        subtitle: Text(payment.createdAt),
                        trailing: MoneyText(payment.totalSatang),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PaymentResultPage(payment: payment),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class StatementPage extends StatelessWidget {
  const StatementPage({super.key, required this.statement});

  final StatementModel statement;

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    final current =
        controller.home?.bills
            .where((bill) => bill.id == statement.id)
            .firstOrNull ??
        statement;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statement)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoBanner(text: l10n.demoBanner, compact: true),
          const SizedBox(height: 16),
          Text(
            current.issuerName(controller.localeCode),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${current.network} · ${l10n.ending} ${current.last4}'),
          const SizedBox(height: 12),
          MoneyText(
            current.fullDueSatang,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          Text('${l10n.minimum} ${formatSatang(current.minDueSatang)}'),
          const SizedBox(height: 8),
          Text(
            '${l10n.dueDate}: ${formatCivilDate(current.dueDate, locale: controller.localeCode)}',
          ),
          Text(
            '${l10n.statementDate}: ${formatCivilDate(current.statementDate, locale: controller.localeCode)}',
          ),
          const SizedBox(height: 8),
          StatusPill(
            label: l10n.reviewLabel(current.reviewState),
            color: BilloColors.ink,
          ),
          const SizedBox(height: 16),
          if (current.reviewState == 'needs_review')
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewPage(statement: current),
                ),
              ),
              child: Text(l10n.needsReview),
            ),
          if (current.selectable)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PayPage(bills: [current]),
                ),
              ),
              child: Text(l10n.reviewPayment),
            ),
        ],
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.statement});

  final StatementModel statement;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final full = TextEditingController(
    text: formatBahtInput(widget.statement.fullDueSatang),
  );
  late final minimum = TextEditingController(
    text: formatBahtInput(widget.statement.minDueSatang),
  );
  late final due = TextEditingController(text: widget.statement.dueDate);
  String? localError;

  @override
  void dispose() {
    full.dispose();
    minimum.dispose();
    due.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.needsReview)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.importHelp),
          const SizedBox(height: 12),
          TextField(
            controller: full,
            decoration: InputDecoration(labelText: l10n.fullAmount),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: minimum,
            decoration: InputDecoration(labelText: l10n.minimum),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: due,
            decoration: InputDecoration(
              labelText: '${l10n.dueDate} YYYY-MM-DD',
            ),
          ),
          if (localError != null || controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                localError ?? controller.errorMessage!,
                style: const TextStyle(color: BilloColors.stamp),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () async {
                    try {
                      final saved = await controller.saveReview(
                        widget.statement.id,
                        StatementPatch(
                          fullDueSatang: parseBahtToSatang(full.text),
                          minDueSatang: parseBahtToSatang(minimum.text),
                          dueDate: due.text.trim(),
                        ),
                      );
                      if (!context.mounted || saved == null) return;
                      setState(() => localError = null);
                    } on FormatException {
                      setState(() => localError = l10n.fullAmount);
                    }
                  },
            child: Text(l10n.save),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.busy
                ? null
                : () async {
                    final saved = await controller.confirmStatement(
                      widget.statement.id,
                    );
                    if (!context.mounted || saved == null) return;
                    Navigator.of(context).pop();
                  },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.import)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoBanner(text: l10n.demoBanner, compact: true),
          const SizedBox(height: 12),
          Text(l10n.importHelp),
          const SizedBox(height: 8),
          for (final sample in controller.samples)
            ListTile(
              tileColor: BilloColors.slip,
              title: Text('${sample.issuer} · ${sample.last4}'),
              subtitle: Text(
                sample.alreadyImported
                    ? l10n.duplicate
                    : formatSatang(sample.fullDueSatang),
              ),
              trailing: FilledButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        final created = await controller.importSample(
                          sample.id,
                        );
                        if (!context.mounted || created == null) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReviewPage(statement: created),
                          ),
                        );
                      },
                child: Text(
                  sample.alreadyImported ? l10n.duplicate : l10n.import,
                ),
              ),
            ),
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.errorMessage!,
                style: const TextStyle(color: BilloColors.stamp),
              ),
            ),
          const SizedBox(height: 20),
          Text(l10n.pdfHelp),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () => controller.importPdf('verified-sample'),
            child: Text(l10n.extractSample),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.busy
                ? null
                : () => controller.importPdf('unsupported-letter'),
            child: Text(l10n.extractOther),
          ),
          if (controller.pdfUnavailable && controller.pdfMessage != null) ...[
            const SizedBox(height: 12),
            PdfResultPanel(
              title: l10n.extractionUnavailable,
              message: controller.pdfMessage!,
              note: l10n.amountsNotGuessed,
            ),
          ],
        ],
      ),
    );
  }
}

class PayPage extends StatelessWidget {
  const PayPage({super.key, required this.bills});

  final List<StatementModel> bills;

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    final total = bills.fold<int>(0, (sum, bill) => sum + bill.fullDueSatang);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewPayment)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoBanner(text: l10n.demoBanner),
          const SizedBox(height: 12),
          Text(l10n.payFull),
          Text(l10n.scripted),
          const SizedBox(height: 12),
          for (final bill in bills)
            ListTile(
              tileColor: BilloColors.slip,
              title: Text(bill.issuerName(controller.localeCode)),
              subtitle: Text(bill.last4),
              trailing: MoneyText(bill.fullDueSatang),
            ),
          const SizedBox(height: 8),
          MoneyText(
            total,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.simulator,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final issuer
              in controller.meta?.simulator ?? const <SimulatorIssuer>[])
            Text('${issuer.name(controller.localeCode)} · ${issuer.outcome}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () async {
                    final payment = await controller.pay(
                      bills.map((bill) => bill.id).toList(),
                    );
                    if (!context.mounted || payment == null) return;
                    await Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PaymentResultPage(payment: payment),
                      ),
                    );
                  },
            child: Text(l10n.simulate),
          ),
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.errorMessage!,
                style: const TextStyle(color: BilloColors.stamp),
              ),
            ),
        ],
      ),
    );
  }
}

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key, required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final l10n = BilloScope.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.result)),
      body: PaymentResultView(payment: payment, l10n: l10n),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoBanner(text: l10n.demoBanner),
          const SizedBox(height: 16),
          Text(
            l10n.language,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const LocaleSwitch(),
          const SizedBox(height: 16),
          Text(
            l10n.gmailTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(l10n.gmailBody),
          const SizedBox(height: 12),
          Text(
            l10n.billTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(l10n.billBody),
          const SizedBox(height: 12),
          Text(l10n.pdfHelp),
          const SizedBox(height: 12),
          Text(
            l10n.privacyTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(l10n.privacyBody),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: controller.busy ? null : controller.reset,
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }
}

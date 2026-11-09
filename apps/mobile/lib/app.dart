import 'package:flutter/material.dart';

import 'api.dart';
import 'controller.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

class BilloScope extends InheritedNotifier<BilloController> {
  const BilloScope({
    super.key,
    required BilloController controller,
    required super.child,
  }) : super(notifier: controller);

  static BilloController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BilloScope>();
    assert(scope != null, 'BilloScope missing');
    return scope!.notifier!;
  }
}

class BilloApp extends StatefulWidget {
  const BilloApp({super.key, required this.api, this.localeCode = 'en'});

  final BilloApi api;
  final String localeCode;

  @override
  State<BilloApp> createState() => _BilloAppState();
}

class _BilloAppState extends State<BilloApp> {
  late final BilloController controller = BilloController(
    widget.api,
    localeCode: widget.localeCode,
  );

  @override
  void initState() {
    super.initState();
    controller.refresh();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BilloScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Billo',
        theme: buildBilloTheme(),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = BilloScope.of(context);
    final l10n = controller.t;
    final pages = const [HomePage(), CardsPage(), ActivityPage()];
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: pages[index]),
          if (index == 0 && controller.selected.isNotEmpty)
            Material(
              key: const Key('pay-bar'),
              color: BilloColors.spineDark,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.billsCount(controller.selected.length),
                              style: const TextStyle(color: BilloColors.cream),
                            ),
                            MoneyText(
                              controller.selectedSatang,
                              style: const TextStyle(
                                color: BilloColors.cream,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BilloColors.cream,
                          foregroundColor: BilloColors.spineDark,
                        ),
                        onPressed: () {
                          final bills = controller.selectedBills;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PayPage(bills: bills),
                            ),
                          );
                        },
                        child: Text(l10n.reviewPayment),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.folder_open),
                label: l10n.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.style_outlined),
                label: l10n.cards,
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long),
                label: l10n.activity,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FolderHeader extends StatelessWidget {
  const FolderHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BilloColors.spine,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 18),
          child: child,
        ),
      ),
    );
  }
}

class LocaleSwitch extends StatelessWidget {
  const LocaleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(context, 'en', 'EN', const Key('locale-en')),
        _chip(context, 'th', 'TH', const Key('locale-th')),
      ],
    );
  }

  Widget _chip(BuildContext context, String code, String label, Key key) {
    final controller = BilloScope.of(context);
    final selected = controller.localeCode == code;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: TextButton(
        key: key,
        style: TextButton.styleFrom(
          foregroundColor: selected ? BilloColors.spineDark : BilloColors.cream,
          backgroundColor: selected ? BilloColors.cream : BilloColors.spineDark,
          minimumSize: const Size(44, 36),
        ),
        onPressed: () => controller.setLocale(code),
        child: Text(label),
      ),
    );
  }
}

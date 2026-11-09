import 'package:billo/api.dart';
import 'package:billo/models.dart';

class ScriptedApi implements BilloApi {
  ScriptedApi()
    : homeModel = HomeModel(
        demo: const DemoClock(
          today: '2026-11-08',
          timeZone: 'Asia/Bangkok',
          noRealMoney: true,
        ),
        totals: const Totals(
          openFullDueSatang: 9752350,
          openMinDueSatang: 491440,
          openCount: 5,
          dueSoonFullDueSatang: 5175050,
          dueSoonCount: 2,
          pendingFullDueSatang: 0,
          pendingCount: 0,
          needsReviewCount: 1,
        ),
        bills: [
          _bill(
            'stmt_bbl_2026-10-18',
            'bbl',
            'Bangkok Bank',
            'กรุงเทพ',
            '2207',
            '2026-11-09',
            890050,
            'confirmed',
            'open',
            'due_soon',
          ),
          _bill(
            'stmt_kbank_2026-10-25',
            'kbank',
            'Kasikorn Bank',
            'กสิกรไทย',
            '4412',
            '2026-11-12',
            4285000,
            'confirmed',
            'open',
            'due_soon',
          ),
          _bill(
            'stmt_ktc_2026-10-15',
            'ktc',
            'KTC',
            'เคทีซี',
            '5564',
            '2026-12-02',
            675000,
            'needs_review',
            'open',
            'later',
          ),
        ],
      );

  final HomeModel homeModel;

  @override
  Future<MetaModel> meta() async =>
      const MetaModel(today: '2026-11-08', simulator: []);

  @override
  Future<HomeModel> home() async => homeModel;

  @override
  Future<List<CardModel>> cards() async => const [];

  @override
  Future<List<PaymentModel>> payments() async => const [];

  @override
  Future<List<SampleModel>> samples() async => const [];

  @override
  Future<StatementModel> statement(String id) async =>
      homeModel.bills.firstWhere((bill) => bill.id == id);

  @override
  Future<StatementModel> importSample(String id) => throw UnimplementedError();

  @override
  Future<PdfImportResult> importPdfFixture(String fixture) async =>
      const PdfImportResult.unavailable('no layout');

  @override
  Future<StatementModel> patchStatement(String id, StatementPatch patch) =>
      throw UnimplementedError();

  @override
  Future<StatementModel> confirmStatement(String id) =>
      throw UnimplementedError();

  @override
  Future<PaymentModel> pay(List<String> statementIds, String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<void> reset() async {}
}

StatementModel _bill(
  String id,
  String issuer,
  String en,
  String th,
  String last4,
  String due,
  int full,
  String review,
  String settlement,
  String bucket,
) {
  return StatementModel(
    id: id,
    cardId: 'card_$issuer',
    issuer: issuer,
    issuerNameEn: en,
    issuerNameTh: th,
    network: 'visa',
    last4: last4,
    periodStart: '2026-09-01',
    periodEnd: '2026-10-01',
    statementDate: '2026-10-01',
    dueDate: due,
    fullDueSatang: full,
    minDueSatang: 100,
    reviewState: review,
    settlementState: settlement,
    source: 'seed',
    dueBucket: bucket,
  );
}

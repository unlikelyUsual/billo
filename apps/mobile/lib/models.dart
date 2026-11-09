class DemoClock {
  const DemoClock({
    required this.today,
    required this.timeZone,
    required this.noRealMoney,
  });

  final String today;
  final String timeZone;
  final bool noRealMoney;

  factory DemoClock.fromJson(Map<String, dynamic> json) {
    return DemoClock(
      today: json['today'] as String,
      timeZone: json['timeZone'] as String,
      noRealMoney: json['noRealMoney'] as bool,
    );
  }
}

class Totals {
  const Totals({
    required this.openFullDueSatang,
    required this.openMinDueSatang,
    required this.openCount,
    required this.dueSoonFullDueSatang,
    required this.dueSoonCount,
    required this.pendingFullDueSatang,
    required this.pendingCount,
    required this.needsReviewCount,
  });

  final int openFullDueSatang;
  final int openMinDueSatang;
  final int openCount;
  final int dueSoonFullDueSatang;
  final int dueSoonCount;
  final int pendingFullDueSatang;
  final int pendingCount;
  final int needsReviewCount;

  factory Totals.fromJson(Map<String, dynamic> json) {
    return Totals(
      openFullDueSatang: _int(json['openFullDueSatang']),
      openMinDueSatang: _int(json['openMinDueSatang']),
      openCount: _int(json['openCount']),
      dueSoonFullDueSatang: _int(json['dueSoonFullDueSatang']),
      dueSoonCount: _int(json['dueSoonCount']),
      pendingFullDueSatang: _int(json['pendingFullDueSatang']),
      pendingCount: _int(json['pendingCount']),
      needsReviewCount: _int(json['needsReviewCount']),
    );
  }
}

class StatementModel {
  const StatementModel({
    required this.id,
    required this.cardId,
    required this.issuer,
    required this.issuerNameEn,
    required this.issuerNameTh,
    required this.network,
    required this.last4,
    required this.periodStart,
    required this.periodEnd,
    required this.statementDate,
    required this.dueDate,
    required this.fullDueSatang,
    required this.minDueSatang,
    required this.reviewState,
    required this.settlementState,
    required this.source,
    required this.dueBucket,
  });

  final String id;
  final String cardId;
  final String issuer;
  final String issuerNameEn;
  final String issuerNameTh;
  final String network;
  final String last4;
  final String periodStart;
  final String periodEnd;
  final String statementDate;
  final String dueDate;
  final int fullDueSatang;
  final int minDueSatang;
  final String reviewState;
  final String settlementState;
  final String source;
  final String dueBucket;

  bool get selectable =>
      reviewState == 'confirmed' &&
      (settlementState == 'open' || settlementState == 'payment_failed');

  String issuerName(String locale) =>
      locale == 'th' ? issuerNameTh : issuerNameEn;

  factory StatementModel.fromJson(Map<String, dynamic> json) {
    return StatementModel(
      id: json['id'] as String,
      cardId: json['cardId'] as String,
      issuer: json['issuer'] as String,
      issuerNameEn: json['issuerNameEn'] as String,
      issuerNameTh: json['issuerNameTh'] as String,
      network: json['network'] as String,
      last4: json['last4'] as String,
      periodStart: json['periodStart'] as String,
      periodEnd: json['periodEnd'] as String,
      statementDate: json['statementDate'] as String,
      dueDate: json['dueDate'] as String,
      fullDueSatang: _int(json['fullDueSatang']),
      minDueSatang: _int(json['minDueSatang']),
      reviewState: json['reviewState'] as String,
      settlementState: json['settlementState'] as String,
      source: json['source'] as String,
      dueBucket: json['dueBucket'] as String,
    );
  }
}

class HomeModel {
  const HomeModel({
    required this.demo,
    required this.totals,
    required this.bills,
  });

  final DemoClock demo;
  final Totals totals;
  final List<StatementModel> bills;

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    final bills = (json['bills'] as List<dynamic>)
        .map((item) => StatementModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return HomeModel(
      demo: DemoClock.fromJson(json['demo'] as Map<String, dynamic>),
      totals: Totals.fromJson(json['totals'] as Map<String, dynamic>),
      bills: bills,
    );
  }
}

class CardModel {
  const CardModel({
    required this.id,
    required this.issuer,
    required this.issuerNameEn,
    required this.issuerNameTh,
    required this.network,
    required this.last4,
    required this.openFullDueSatang,
    required this.openStatementCount,
  });

  final String id;
  final String issuer;
  final String issuerNameEn;
  final String issuerNameTh;
  final String network;
  final String last4;
  final int openFullDueSatang;
  final int openStatementCount;

  String issuerName(String locale) =>
      locale == 'th' ? issuerNameTh : issuerNameEn;

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      issuer: json['issuer'] as String,
      issuerNameEn: json['issuerNameEn'] as String,
      issuerNameTh: json['issuerNameTh'] as String,
      network: json['network'] as String,
      last4: json['last4'] as String,
      openFullDueSatang: _int(json['openFullDueSatang']),
      openStatementCount: _int(json['openStatementCount']),
    );
  }
}

class SampleModel {
  const SampleModel({
    required this.id,
    required this.issuer,
    required this.last4,
    required this.dueDate,
    required this.fullDueSatang,
    required this.alreadyImported,
  });

  final String id;
  final String issuer;
  final String last4;
  final String dueDate;
  final int fullDueSatang;
  final bool alreadyImported;

  factory SampleModel.fromJson(Map<String, dynamic> json) {
    return SampleModel(
      id: json['id'] as String,
      issuer: json['issuer'] as String,
      last4: json['last4'] as String,
      dueDate: json['dueDate'] as String,
      fullDueSatang: _int(json['fullDueSatang']),
      alreadyImported: json['alreadyImported'] as bool,
    );
  }
}

class SimulatorIssuer {
  const SimulatorIssuer({
    required this.issuer,
    required this.nameEn,
    required this.nameTh,
    required this.outcome,
  });

  final String issuer;
  final String nameEn;
  final String nameTh;
  final String outcome;

  String name(String locale) => locale == 'th' ? nameTh : nameEn;

  factory SimulatorIssuer.fromJson(Map<String, dynamic> json) {
    return SimulatorIssuer(
      issuer: json['issuer'] as String,
      nameEn: json['nameEn'] as String,
      nameTh: json['nameTh'] as String,
      outcome: json['outcome'] as String,
    );
  }
}

class MetaModel {
  const MetaModel({required this.today, required this.simulator});

  final String today;
  final List<SimulatorIssuer> simulator;

  factory MetaModel.fromJson(Map<String, dynamic> json) {
    final simulator = (json['simulator'] as List<dynamic>)
        .map((item) => SimulatorIssuer.fromJson(item as Map<String, dynamic>))
        .toList();
    return MetaModel(today: json['today'] as String, simulator: simulator);
  }
}

class PaymentItemModel {
  const PaymentItemModel({
    required this.statementId,
    required this.issuer,
    required this.last4,
    required this.amountSatang,
    required this.status,
    required this.outcomeMessage,
  });

  final String statementId;
  final String issuer;
  final String last4;
  final int amountSatang;
  final String status;
  final String outcomeMessage;

  factory PaymentItemModel.fromJson(Map<String, dynamic> json) {
    return PaymentItemModel(
      statementId: json['statementId'] as String,
      issuer: json['issuer'] as String,
      last4: json['last4'] as String,
      amountSatang: _int(json['amountSatang']),
      status: json['status'] as String,
      outcomeMessage: json['outcomeMessage'] as String,
    );
  }
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.createdAt,
    required this.batchStatus,
    required this.autoRetry,
    required this.items,
  });

  final String id;
  final String createdAt;
  final String batchStatus;
  final bool autoRetry;
  final List<PaymentItemModel> items;

  int get totalSatang => items.fold(0, (sum, item) => sum + item.amountSatang);

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((item) => PaymentItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return PaymentModel(
      id: json['id'] as String,
      createdAt: json['createdAt'] as String,
      batchStatus: json['batchStatus'] as String,
      autoRetry: json['autoRetry'] as bool,
      items: items,
    );
  }
}

class PdfImportResult {
  const PdfImportResult.unavailable(this.message)
    : status = 'unavailable',
      statement = null;
  const PdfImportResult.extracted(this.statement)
    : status = 'extracted',
      message = null;

  final String status;
  final String? message;
  final StatementModel? statement;
}

class StatementPatch {
  const StatementPatch({this.fullDueSatang, this.minDueSatang, this.dueDate});

  final int? fullDueSatang;
  final int? minDueSatang;
  final String? dueDate;

  Map<String, Object?> toJson() => {
    if (fullDueSatang != null) 'fullDueSatang': fullDueSatang,
    if (minDueSatang != null) 'minDueSatang': minDueSatang,
    if (dueDate != null) 'dueDate': dueDate,
  };
}

int _int(Object? value) {
  if (value is int) return value;
  throw FormatException('Expected an integer satang amount, got $value');
}

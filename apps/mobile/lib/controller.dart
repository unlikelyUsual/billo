import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'l10n.dart';
import 'models.dart';

class BilloController extends ChangeNotifier {
  BilloController(this.api, {this.localeCode = 'en'});

  final BilloApi api;
  String localeCode;
  L10n get t => L10n(localeCode);

  bool loading = true;
  bool busy = false;
  String? errorMessage;
  HomeModel? home;
  MetaModel? meta;
  List<CardModel> cards = const [];
  List<PaymentModel> payments = const [];
  List<SampleModel> samples = const [];
  final Set<String> selected = {};
  String? pdfMessage;
  bool pdfUnavailable = false;
  String? _payKey;
  String? _payFingerprint;
  bool _disposed = false;

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        api.meta(),
        api.home(),
        api.cards(),
        api.payments(),
        api.samples(),
      ]);
      meta = results[0] as MetaModel;
      home = results[1] as HomeModel;
      cards = results[2] as List<CardModel>;
      payments = results[3] as List<PaymentModel>;
      samples = results[4] as List<SampleModel>;
      selected.removeWhere(
        (id) =>
            !(home?.bills.any((bill) => bill.id == id && bill.selectable) ??
                false),
      );
      errorMessage = null;
    } on ApiException catch (error) {
      errorMessage = error.code == 'api_unreachable'
          ? t.apiDown
          : error.message;
    } catch (_) {
      errorMessage = t.apiDown;
    } finally {
      loading = false;
      _notify();
    }
  }

  void setLocale(String code) {
    localeCode = code;
    if (errorMessage != null && home == null) {
      errorMessage = t.apiDown;
    }
    _notify();
  }

  void toggle(String id) {
    if (!selected.add(id)) {
      selected.remove(id);
    }
    _notify();
  }

  void selectPayable() {
    final bills = home?.bills.where((bill) => bill.selectable) ?? const [];
    selected
      ..clear()
      ..addAll(bills.map((bill) => bill.id));
    _notify();
  }

  void clearSelection() {
    selected.clear();
    _notify();
  }

  List<StatementModel> get selectedBills =>
      home?.bills.where((bill) => selected.contains(bill.id)).toList() ??
      const [];

  int get selectedSatang =>
      selectedBills.fold(0, (sum, bill) => sum + bill.fullDueSatang);

  Future<StatementModel?> importSample(String id) =>
      _guard(() => api.importSample(id));

  Future<PdfImportResult?> importPdf(String fixture) async {
    busy = true;
    _notify();
    try {
      final result = await api.importPdfFixture(fixture);
      pdfUnavailable = result.status == 'unavailable';
      pdfMessage = result.message ?? result.statement?.issuerNameEn;
      errorMessage = null;
      if (result.statement != null) {
        await refresh();
      }
      return result;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<StatementModel?> saveReview(String id, StatementPatch patch) =>
      _guard(() => api.patchStatement(id, patch));

  Future<StatementModel?> confirmStatement(String id) =>
      _guard(() => api.confirmStatement(id));

  Future<PaymentModel?> pay(List<String> ids) async {
    final sorted = [...ids]..sort();
    final fingerprint = sorted.join('\u0001');
    final key = _payKey != null && _payFingerprint == fingerprint
        ? _payKey!
        : _newKey();
    busy = true;
    _notify();
    try {
      final payment = await api.pay(sorted, key);
      _payKey = null;
      _payFingerprint = null;
      selected.clear();
      errorMessage = null;
      await refresh();
      return payment;
    } on ApiException catch (error) {
      final network = error.status == 0 || error.code == 'api_unreachable';
      if (network) {
        _payKey = key;
        _payFingerprint = fingerprint;
        errorMessage = t.networkDuringPay;
      } else {
        _payKey = null;
        _payFingerprint = null;
        errorMessage = error.message;
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> reset() async {
    await _guard(() async {
      await api.reset();
      pdfMessage = null;
      pdfUnavailable = false;
      selected.clear();
      return home?.bills.first;
    });
    await refresh();
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    busy = true;
    _notify();
    try {
      final value = await action();
      errorMessage = null;
      await refresh();
      return value;
    } on ApiException catch (error) {
      errorMessage = error.code == 'api_unreachable'
          ? t.apiDown
          : error.message;
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final text = bytes.map(hex).join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

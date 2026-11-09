import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract class BilloApi {
  Future<MetaModel> meta();
  Future<HomeModel> home();
  Future<List<CardModel>> cards();
  Future<StatementModel> statement(String id);
  Future<List<SampleModel>> samples();
  Future<StatementModel> importSample(String id);
  Future<PdfImportResult> importPdfFixture(String fixture);
  Future<StatementModel> patchStatement(String id, StatementPatch patch);
  Future<StatementModel> confirmStatement(String id);
  Future<List<PaymentModel>> payments();
  Future<PaymentModel> pay(List<String> statementIds, String idempotencyKey);
  Future<void> reset();
}

class HttpBilloApi implements BilloApi {
  HttpBilloApi(String baseUrl, {http.Client? client})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  @override
  Future<MetaModel> meta() async =>
      MetaModel.fromJson(await _json('GET', '/v1/meta'));

  @override
  Future<HomeModel> home() async =>
      HomeModel.fromJson(await _json('GET', '/v1/home'));

  @override
  Future<List<CardModel>> cards() async {
    final body = await _json('GET', '/v1/cards');
    return (body['cards'] as List<dynamic>)
        .map((item) => CardModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StatementModel> statement(String id) async {
    final body = await _json('GET', '/v1/statements/$id');
    return StatementModel.fromJson(body['statement'] as Map<String, dynamic>);
  }

  @override
  Future<List<SampleModel>> samples() async {
    final body = await _json('GET', '/v1/samples');
    return (body['samples'] as List<dynamic>)
        .map((item) => SampleModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StatementModel> importSample(String id) async {
    final body = await _json('POST', '/v1/imports/sample', {
      'sampleId': id,
    }, true);
    return StatementModel.fromJson(body['statement'] as Map<String, dynamic>);
  }

  @override
  Future<PdfImportResult> importPdfFixture(String fixture) async {
    final response = await _send('POST', '/v1/imports/pdf', {
      'fixture': fixture,
    });
    final body = _decode(response.body);
    if (response.statusCode == 422 && body['status'] == 'unavailable') {
      final error = body['error'] as Map<String, dynamic>;
      return PdfImportResult.unavailable(error['message'] as String);
    }
    if (response.statusCode == 201) {
      return PdfImportResult.extracted(
        StatementModel.fromJson(body['statement'] as Map<String, dynamic>),
      );
    }
    throw _error(response.statusCode, body);
  }

  @override
  Future<StatementModel> patchStatement(String id, StatementPatch patch) async {
    final body = await _json('PATCH', '/v1/statements/$id', patch.toJson());
    return StatementModel.fromJson(body['statement'] as Map<String, dynamic>);
  }

  @override
  Future<StatementModel> confirmStatement(String id) async {
    final body = await _json('POST', '/v1/statements/$id/confirm', {});
    return StatementModel.fromJson(body['statement'] as Map<String, dynamic>);
  }

  @override
  Future<List<PaymentModel>> payments() async {
    final body = await _json('GET', '/v1/payments');
    return (body['payments'] as List<dynamic>)
        .map((item) => PaymentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PaymentModel> pay(
    List<String> statementIds,
    String idempotencyKey,
  ) async {
    final response = await _send(
      'POST',
      '/v1/payments',
      {'statementIds': statementIds},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final body = _decode(response.body);
    if (response.statusCode == 201) {
      return PaymentModel.fromJson(body['payment'] as Map<String, dynamic>);
    }
    throw _error(response.statusCode, body);
  }

  @override
  Future<void> reset() async {
    await _json('POST', '/v1/demo/reset', {});
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, [
    Map<String, Object?>? payload,
    bool created = false,
  ]) async {
    final response = await _send(method, path, payload);
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : _decode(response.body);
    final ok =
        response.statusCode == 200 || (created && response.statusCode == 201);
    if (!ok) {
      throw _error(response.statusCode, body);
    }
    return body;
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, Object?>? payload, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = {'accept': 'application/json', ...?headers};
    try {
      final Future<http.Response> call;
      if (method == 'GET') {
        call = client.get(uri, headers: requestHeaders);
      } else if (method == 'PATCH') {
        call = client.patch(
          uri,
          headers: {...requestHeaders, 'content-type': 'application/json'},
          body: jsonEncode(payload),
        );
      } else {
        call = client.post(
          uri,
          headers: {...requestHeaders, 'content-type': 'application/json'},
          body: jsonEncode(payload ?? {}),
        );
      }
      return await call.timeout(const Duration(seconds: 12));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'api_unreachable', 'api_unreachable');
    }
  }

  Map<String, dynamic> _decode(String body) {
    final decoded = jsonDecode(body);
    return decoded as Map<String, dynamic>;
  }

  ApiException _error(int status, Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(
        status,
        error['code'] as String? ?? 'error',
        error['message'] as String? ?? 'Request failed',
      );
    }
    return ApiException(status, 'error', 'Request failed');
  }
}

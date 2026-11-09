import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addDays,
  assertNoSecrets,
  batchStatus,
  formatBangkokIso,
  hashBody,
  isRealDate,
  jsonHasNonIntegerNumber,
  looksLikePan,
} from '../src/domain';
import { buildApp } from '../src/app';
import { HttpError } from '../src/errors';
import {
  buildTextPdf,
  extractStatementPdf,
  UNSUPPORTED_LETTER_LINES,
  VERIFIED_SAMPLE_LINES,
} from '../src/pdf';
import { createStore } from '../src/store';

test('civil dates do not shift across month ends', () => {
  assert.equal(isRealDate('2026-11-08'), true);
  assert.equal(isRealDate('2026-02-29'), false);
  assert.equal(isRealDate('2024-02-29'), true);
  assert.equal(addDays('2026-11-30', 2), '2026-12-02');
  assert.equal(addDays('2026-11-08', 7), '2026-11-15');
});

test('timestamps are labeled Asia/Bangkok', () => {
  assert.equal(formatBangkokIso(new Date('2026-11-07T17:00:00.000Z')), '2026-11-08T00:00:00+07:00');
  assert.equal(formatBangkokIso(new Date('2026-11-08T02:00:00.000Z')), '2026-11-08T09:00:00+07:00');
});

test('batch status treats any pending item as action required', () => {
  assert.equal(batchStatus(['succeeded', 'succeeded']), 'succeeded');
  assert.equal(batchStatus(['failed']), 'failed');
  assert.equal(batchStatus(['succeeded', 'failed']), 'partial');
  assert.equal(batchStatus(['succeeded', 'pending']), 'action_required');
  assert.equal(batchStatus(['failed', 'pending']), 'action_required');
});

test('pan detector ignores last4 and flags full numbers', () => {
  assert.equal(looksLikePan('4412'), false);
  assert.equal(looksLikePan('4111 1111 1111 1111'), true);
  assert.equal(looksLikePan('note 4111111111111111'), true);
  assert.equal(jsonHasNonIntegerNumber('{"fullDueSatang":1500000}'), false);
  assert.equal(jsonHasNonIntegerNumber('{"fullDueSatang":15000.5}'), true);
  assert.throws(
    () => assertNoSecrets({ tokens: 'secret' }),
    (error: unknown) => error instanceof HttpError && error.code === 'secret_field_rejected',
  );
});

test('sorting statement ids makes the payment hash order-independent', () => {
  const left = ['stmt_bbl_2026-10-18', 'stmt_kbank_2026-10-25'];
  const right = ['stmt_kbank_2026-10-25', 'stmt_bbl_2026-10-18'];
  assert.equal(hashBody({ statementIds: [...left].sort() }), hashBody({ statementIds: [...right].sort() }));
});

test('marked sample PDF extracts exact satang and other files do not', () => {
  const extracted = extractStatementPdf(buildTextPdf(VERIFIED_SAMPLE_LINES));
  assert.equal(extracted.status, 'extracted');
  if (extracted.status !== 'extracted') return;
  assert.equal(extracted.draft.fullDueSatang, 1500000);
  assert.equal(extracted.draft.minDueSatang, 75000);
  assert.equal(extracted.draft.issuer, 'ttb');

  const letter = extractStatementPdf(buildTextPdf(UNSUPPORTED_LETTER_LINES));
  assert.equal(letter.status, 'unavailable');
  if (letter.status === 'unavailable') {
    assert.equal(letter.reason, 'layout_not_verified');
  }

  const compressed = extractStatementPdf(
    Buffer.from('%PDF-1.4\n1 0 obj << /Filter /FlateDecode >> endobj\n%%EOF\n'),
  );
  assert.equal(compressed.status, 'unavailable');
  if (compressed.status === 'unavailable') assert.equal(compressed.reason, 'compressed_pdf');

  const secret = extractStatementPdf(
    buildTextPdf([...VERIFIED_SAMPLE_LINES, 'pan=4111111111111111']),
  );
  assert.equal(secret.status, 'unavailable');
  if (secret.status === 'unavailable') assert.equal(secret.reason, 'secret_field_rejected');
});

test('idempotency begin reports in progress until completed', () => {
  const store = createStore();
  const hash = hashBody({ statementIds: ['stmt_kbank_2026-10-25'] });
  assert.equal(store.beginIdempotency('key-progress', hash).type, 'start');
  assert.equal(store.beginIdempotency('key-progress', hash).type, 'in_progress');
  store.completeIdempotency('key-progress', 201, { payment: { id: 'pay_x' } });
  assert.equal(store.beginIdempotency('key-progress', 'other').type, 'conflict');
  const replay = store.beginIdempotency('key-progress', hash);
  assert.equal(replay.type, 'replay');
});

test('app boots the seeded ledger', async () => {
  const app = buildApp();
  const response = await app.inject({ method: 'GET', url: '/health' });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().ok, true);
  await app.close();
});

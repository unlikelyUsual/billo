import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import { buildApp } from '../src/app';
import { looksLikePan } from '../src/domain';
import { buildTextPdf, UNSUPPORTED_LETTER_LINES, VERIFIED_SAMPLE_LINES } from '../src/pdf';

const fixtureDir = path.resolve(__dirname, '../../../packages/contracts/fixtures');

function walk(value: unknown, keys: string[], numbers: number[], strings: string[]): void {
  if (Array.isArray(value)) {
    for (const item of value) walk(item, keys, numbers, strings);
    return;
  }
  if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      keys.push(key);
      walk(item, keys, numbers, strings);
    }
    return;
  }
  if (typeof value === 'number') numbers.push(value);
  if (typeof value === 'string') strings.push(value);
}

async function pay(
  app: ReturnType<typeof buildApp>,
  ids: string[],
  key: string,
): Promise<{ statusCode: number; body: Record<string, unknown>; headers: Record<string, unknown> }> {
  const response = await app.inject({
    method: 'POST',
    url: '/v1/payments',
    headers: { 'idempotency-key': key },
    payload: { statementIds: ids },
  });
  return {
    statusCode: response.statusCode,
    body: response.json() as Record<string, unknown>,
    headers: response.headers,
  };
}

test('home totals match the seeded Bangkok ledger', async () => {
  const app = buildApp();
  const body = (await app.inject({ method: 'GET', url: '/v1/home' })).json();
  assert.equal(body.demo.today, '2026-11-08');
  assert.equal(body.demo.timeZone, 'Asia/Bangkok');
  assert.equal(body.totals.openFullDueSatang, 9752350);
  assert.equal(body.totals.openMinDueSatang, 491440);
  assert.equal(body.totals.dueSoonFullDueSatang, 5175050);
  assert.equal(body.totals.dueSoonCount, 2);
  assert.equal(body.totals.openCount, 5);
  assert.equal(body.totals.needsReviewCount, 1);
  assert.equal(body.totals.overdueCount, 0);
  assert.equal(body.totals.pendingCount, 0);
  const settled = body.bills.find((bill: { id: string }) => bill.id === 'stmt_kbank_2026-09-25');
  assert.equal(settled, undefined);
  await app.close();
});

test('secret fields and full card numbers are rejected without an echo', async () => {
  const app = buildApp();
  const response = await app.inject({
    method: 'POST',
    url: '/v1/imports/sample',
    payload: { sampleId: 'ttb-2026-10', cvv: '123', pan: '4111111111111111' },
  });
  assert.equal(response.statusCode, 400);
  assert.equal(response.json().error.code, 'secret_field_rejected');
  assert.equal(response.body.includes('4111111111111111'), false);
  assert.equal(response.body.includes('123'), false);
  const cards = (await app.inject({ method: 'GET', url: '/v1/cards' })).json();
  const strings: string[] = [];
  walk(cards, [], [], strings);
  for (const value of strings) assert.equal(looksLikePan(value), false);
  await app.close();
});

test('sample import is editable, validated, and duplicate-aware', async () => {
  const app = buildApp();
  const created = await app.inject({
    method: 'POST',
    url: '/v1/imports/sample',
    payload: { sampleId: 'ttb-2026-10' },
  });
  assert.equal(created.statusCode, 201);
  const statement = created.json().statement;
  assert.equal(statement.reviewState, 'needs_review');
  assert.equal(statement.fullDueSatang, 1500000);
  assert.equal(statement.last4, '7781');

  const duplicate = await app.inject({
    method: 'POST',
    url: '/v1/imports/sample',
    payload: { sampleId: 'ttb-2026-10' },
  });
  assert.equal(duplicate.statusCode, 409);
  assert.equal(duplicate.json().error.code, 'duplicate_statement');

  const seeded = await app.inject({
    method: 'POST',
    url: '/v1/imports/sample',
    payload: { sampleId: 'kbank-already-on-file' },
  });
  assert.equal(seeded.statusCode, 409);
  assert.equal(seeded.json().error.details.existingStatementId, 'stmt_kbank_2026-10-25');

  const invalid = await app.inject({
    method: 'PATCH',
    url: `/v1/statements/${statement.id}`,
    payload: { minDueSatang: 1600000 },
  });
  assert.equal(invalid.statusCode, 400);
  assert.equal(invalid.json().error.details[0].code, 'min_exceeds_full');

  const patched = await app.inject({
    method: 'PATCH',
    url: `/v1/statements/${statement.id}`,
    payload: { fullDueSatang: 1600000, minDueSatang: 80000, dueDate: '2026-11-21' },
  });
  assert.equal(patched.statusCode, 200);
  assert.equal(patched.json().statement.fullDueSatang, 1600000);

  const blocked = await app.inject({
    method: 'POST',
    url: '/v1/payments',
    headers: { 'idempotency-key': 'needs-review-pay' },
    payload: { statementIds: [statement.id] },
  });
  assert.equal(blocked.statusCode, 409);
  assert.equal(blocked.json().error.code, 'statement_not_payable');

  const confirmed = await app.inject({
    method: 'POST',
    url: `/v1/statements/${statement.id}/confirm`,
  });
  assert.equal(confirmed.json().statement.reviewState, 'confirmed');
  const locked = await app.inject({
    method: 'PATCH',
    url: `/v1/statements/${statement.id}`,
    payload: { fullDueSatang: 1 },
  });
  assert.equal(locked.statusCode, 409);
  assert.equal(locked.json().error.code, 'not_editable');

  const home = (await app.inject({ method: 'GET', url: '/v1/home' })).json();
  assert.equal(home.totals.openFullDueSatang, 9752350 + 1600000);
  await app.close();
});

test('payments are scripted per issuer and idempotent', async () => {
  const app = buildApp({ clock: () => new Date('2026-11-08T02:00:00.000Z') });
  const ids = ['stmt_kbank_2026-10-25', 'stmt_bbl_2026-10-18', 'stmt_krungsri_2026-10-28'];
  const first = await pay(app, [ids[2]!, ids[0]!, ids[1]!], 'pay-mixed-001');
  assert.equal(first.statusCode, 201);
  assert.equal(first.headers['idempotency-replay'], 'false');
  const payment = first.body.payment as {
    batchStatus: string;
    autoRetry: boolean;
    createdAt: string;
    items: Array<{ issuer: string; status: string }>;
  };
  assert.equal(payment.autoRetry, false);
  assert.equal(payment.batchStatus, 'action_required');
  assert.equal(payment.createdAt, '2026-11-08T09:00:00+07:00');
  const byIssuer = Object.fromEntries(payment.items.map((item) => [item.issuer, item.status]));
  assert.equal(byIssuer.kbank, 'succeeded');
  assert.equal(byIssuer.bbl, 'failed');
  assert.equal(byIssuer.krungsri, 'pending');

  const replay = await pay(app, ids, 'pay-mixed-001');
  assert.equal(replay.statusCode, 201);
  assert.equal(replay.headers['idempotency-replay'], 'true');
  assert.deepEqual(replay.body, first.body);

  const conflict = await pay(app, ['stmt_scb_2026-10-20'], 'pay-mixed-001');
  assert.equal(conflict.statusCode, 409);
  assert.equal((conflict.body.error as { code: string }).code, 'idempotency_conflict');

  const home = (await app.inject({ method: 'GET', url: '/v1/home' })).json();
  assert.equal(home.totals.openFullDueSatang, 9752350 - 4285000 - 2334500);
  assert.equal(home.totals.pendingFullDueSatang, 2334500);
  const bbl = home.bills.find((bill: { id: string }) => bill.id === 'stmt_bbl_2026-10-18');
  assert.equal(bbl.settlementState, 'payment_failed');

  const againPending = await pay(app, ['stmt_krungsri_2026-10-28'], 'pay-krungsri-again');
  assert.equal(againPending.statusCode, 409);
  assert.equal((againPending.body.error as { code: string }).code, 'statement_not_payable');

  const retried = await app.inject({ method: 'POST', url: `/v1/payments/${(first.body.payment as { id: string }).id}/retry` });
  assert.equal(retried.statusCode, 409);
  assert.equal(retried.json().error.code, 'no_auto_retry');
  const still = (await app.inject({ method: 'GET', url: `/v1/payments/${(first.body.payment as { id: string }).id}` })).json();
  assert.deepEqual(still.payment, first.body.payment);

  const failedAgain = await pay(app, ['stmt_bbl_2026-10-18'], 'pay-bbl-again');
  assert.equal(failedAgain.statusCode, 201);
  const failedItem = (failedAgain.body.payment as { items: Array<{ status: string }> }).items[0];
  assert.equal(failedItem?.status, 'failed');
  await app.close();
});

test('a rejected payment does not settle the valid bill in the same request', async () => {
  const app = buildApp();
  const response = await pay(app, ['stmt_kbank_2026-10-25', 'stmt_ktc_2026-10-15'], 'pay-atomic-001');
  assert.equal(response.statusCode, 409);
  const home = (await app.inject({ method: 'GET', url: '/v1/home' })).json();
  const kbank = home.bills.find((bill: { id: string }) => bill.id === 'stmt_kbank_2026-10-25');
  assert.equal(kbank.settlementState, 'open');
  assert.equal(home.totals.openFullDueSatang, 9752350);
  await app.close();
});

test('missing idempotency key is rejected', async () => {
  const app = buildApp();
  const response = await app.inject({
    method: 'POST',
    url: '/v1/payments',
    payload: { statementIds: ['stmt_scb_2026-10-20'] },
  });
  assert.equal(response.statusCode, 400);
  assert.equal(response.json().error.code, 'idempotency_key_required');
  await app.close();
});

test('pdf fixture import and unavailable uploads do not invent amounts', async () => {
  fs.writeFileSync(path.join(fixtureDir, 'verified-sample.pdf'), buildTextPdf(VERIFIED_SAMPLE_LINES));
  fs.writeFileSync(path.join(fixtureDir, 'unsupported-letter.pdf'), buildTextPdf(UNSUPPORTED_LETTER_LINES));
  const app = buildApp();
  const extracted = await app.inject({
    method: 'POST',
    url: '/v1/imports/pdf',
    payload: { fixture: 'verified-sample' },
  });
  assert.equal(extracted.statusCode, 201);
  assert.equal(extracted.json().statement.fullDueSatang, 1500000);
  assert.equal(extracted.json().statement.source, 'pdf_import');

  const duplicate = await app.inject({
    method: 'POST',
    url: '/v1/imports/pdf',
    headers: { 'content-type': 'application/pdf' },
    payload: buildTextPdf(VERIFIED_SAMPLE_LINES),
  });
  assert.equal(duplicate.statusCode, 409);
  assert.equal(duplicate.json().error.code, 'duplicate_statement');

  const unavailable = await app.inject({
    method: 'POST',
    url: '/v1/imports/pdf',
    payload: { fixture: 'unsupported-letter' },
  });
  assert.equal(unavailable.statusCode, 422);
  const keys: string[] = [];
  const numbers: number[] = [];
  walk(unavailable.json(), keys, numbers, []);
  assert.deepEqual(numbers, []);
  assert.equal(keys.some((key) => /satang|amount/i.test(key)), false);
  assert.equal(unavailable.json().error.reason, 'layout_not_verified');

  const traversal = await app.inject({
    method: 'POST',
    url: '/v1/imports/pdf',
    payload: { fixture: '../demo.json' },
  });
  assert.equal(traversal.statusCode, 400);
  await app.close();
});

test('reset restores the seed', async () => {
  const app = buildApp();
  await app.inject({
    method: 'POST',
    url: '/v1/payments',
    headers: { 'idempotency-key': 'pay-before-reset' },
    payload: { statementIds: ['stmt_scb_2026-10-20'] },
  });
  const reset = await app.inject({ method: 'POST', url: '/v1/demo/reset' });
  assert.equal(reset.statusCode, 200);
  const home = (await app.inject({ method: 'GET', url: '/v1/home' })).json();
  assert.equal(home.totals.openFullDueSatang, 9752350);
  const history = (await app.inject({ method: 'GET', url: '/v1/payments' })).json();
  assert.equal(history.payments.length, 1);
  assert.equal(history.payments[0].id, 'pay_seed_kbank_sep');
  await app.close();
});

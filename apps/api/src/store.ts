import {
  batchStatus,
  countsAsOpen,
  draftSchema,
  dueBucket,
  fingerprint,
  formatBangkokIso,
  hashBody,
  isRealDate,
  outcomeMessage,
  payableReason,
  zodDetails,
  type BatchStatus,
  type Draft,
  type DueBucket,
  type IssuerId,
  type Network,
  type Outcome,
  type ReviewState,
  type SettlementState,
  type StatementSource,
} from './domain';
import { HttpError } from './errors';
import { loadFixture, type DemoFixture } from './fixture';

export type Clock = () => Date;

export type CardRecord = {
  id: string;
  issuer: IssuerId;
  network: Network;
  last4: string;
};

export type StatementRecord = {
  id: string;
  cardId: string;
  periodStart: string;
  periodEnd: string;
  statementDate: string;
  dueDate: string;
  fullDueSatang: number;
  minDueSatang: number;
  currency: 'THB';
  reviewState: ReviewState;
  settlementState: SettlementState;
  source: StatementSource;
  fingerprint: string;
};

export type PaymentItem = {
  statementId: string;
  issuer: IssuerId;
  last4: string;
  amountSatang: number;
  status: Outcome;
  simulatorCode: string;
};

export type PaymentRecord = {
  id: string;
  idempotencyKey: string;
  createdAt: string;
  autoRetry: false;
  batchStatus: BatchStatus;
  items: PaymentItem[];
};

type IdempotencyRecord =
  | { state: 'in_progress'; hash: string }
  | { state: 'done'; hash: string; statusCode: number; body: unknown };

export type IdempotencyDecision =
  | { type: 'start' }
  | { type: 'replay'; statusCode: number; body: unknown }
  | { type: 'conflict' }
  | { type: 'in_progress' };

export type StatementDto = {
  id: string;
  cardId: string;
  issuer: IssuerId;
  issuerNameEn: string;
  issuerNameTh: string;
  network: Network;
  last4: string;
  periodStart: string;
  periodEnd: string;
  statementDate: string;
  dueDate: string;
  fullDueSatang: number;
  minDueSatang: number;
  currency: 'THB';
  reviewState: ReviewState;
  settlementState: SettlementState;
  source: StatementSource;
  dueBucket: DueBucket;
};

export type PaymentDto = {
  id: string;
  idempotencyKey: string;
  createdAt: string;
  autoRetry: false;
  batchStatus: BatchStatus;
  items: Array<
    PaymentItem & {
      outcomeMessage: string;
    }
  >;
};

const bucketRank: Record<DueBucket, number> = {
  overdue: 0,
  due_soon: 1,
  later: 2,
};

export class MemoryStore {
  readonly cards = new Map<string, CardRecord>();
  readonly statements = new Map<string, StatementRecord>();
  readonly payments = new Map<string, PaymentRecord>();
  private readonly idempotency = new Map<string, IdempotencyRecord>();
  private importSeq = 1;
  private paymentSeq = 1;

  constructor(
    private readonly fixture: DemoFixture,
    readonly today: string,
    private readonly clock: Clock,
  ) {
    if (!isRealDate(today)) {
      throw new Error(`DEMO_TODAY must be a real calendar date, received ${today}`);
    }
    this.reset();
  }

  reset(): void {
    this.cards.clear();
    this.statements.clear();
    this.payments.clear();
    this.idempotency.clear();
    this.importSeq = 1;
    this.paymentSeq = 1;
    const data = structuredClone(this.fixture);
    for (const card of data.cards) {
      this.cards.set(card.id, card);
    }
    for (const statement of data.statements) {
      const card = this.cards.get(statement.cardId);
      if (!card) {
        throw new Error(`Seed statement ${statement.id} references missing card ${statement.cardId}`);
      }
      const record: StatementRecord = {
        ...statement,
        fingerprint: fingerprint(card.issuer, card.last4, statement.periodEnd),
      };
      this.statements.set(record.id, record);
    }
    const seen = new Set<string>();
    for (const statement of this.statements.values()) {
      if (seen.has(statement.fingerprint)) {
        throw new Error(`Duplicate seed fingerprint ${statement.fingerprint}`);
      }
      seen.add(statement.fingerprint);
    }
    for (const payment of data.payments) {
      const items: PaymentItem[] = payment.items.map((item) => {
        const statement = this.statements.get(item.statementId);
        if (!statement) {
          throw new Error(`Seed payment references missing statement ${item.statementId}`);
        }
        if (item.amountSatang !== statement.fullDueSatang) {
          throw new Error(`Seed payment amount does not match ${item.statementId}`);
        }
        const card = this.requireCard(statement.cardId);
        return {
          statementId: item.statementId,
          issuer: card.issuer,
          last4: card.last4,
          amountSatang: item.amountSatang,
          status: item.status,
          simulatorCode: item.simulatorCode,
        };
      });
      const record: PaymentRecord = {
        id: payment.id,
        idempotencyKey: payment.idempotencyKey,
        createdAt: payment.createdAt,
        autoRetry: false,
        batchStatus: batchStatus(items.map((item) => item.status)),
        items,
      };
      this.payments.set(record.id, record);
      this.idempotency.set(payment.idempotencyKey, {
        state: 'done',
        hash: hashBody({ statementIds: items.map((item) => item.statementId) }),
        statusCode: 201,
        body: { payment: this.paymentDto(record) },
      });
    }
  }

  meta(): {
    service: 'billo-api';
    demo: true;
    noRealMoney: true;
    timeZone: 'Asia/Bangkok';
    today: string;
    currency: 'THB';
    amountUnit: 'satang';
    gmail: 'not_connected';
    billPay: 'not_connected';
    pdfExtraction: 'marked-uncompressed-sample-only';
    autoRetry: false;
    simulator: Array<{
      issuer: IssuerId;
      nameEn: string;
      nameTh: string;
      outcome: Outcome;
      outcomeCode: string;
    }>;
  } {
    const issuers = Object.entries(this.fixture.issuers) as Array<
      [IssuerId, DemoFixture['issuers']['kbank']]
    >;
    return {
      service: 'billo-api',
      demo: true,
      noRealMoney: true,
      timeZone: 'Asia/Bangkok',
      today: this.today,
      currency: 'THB',
      amountUnit: 'satang',
      gmail: 'not_connected',
      billPay: 'not_connected',
      pdfExtraction: 'marked-uncompressed-sample-only',
      autoRetry: false,
      simulator: issuers.map(([issuer, info]) => ({
        issuer,
        nameEn: info.nameEn,
        nameTh: info.nameTh,
        outcome: info.outcome,
        outcomeCode: info.outcomeCode,
      })),
    };
  }

  home(): {
    demo: {
      today: string;
      timeZone: 'Asia/Bangkok';
      noRealMoney: true;
      currency: 'THB';
      amountUnit: 'satang';
    };
    totals: {
      openFullDueSatang: number;
      openMinDueSatang: number;
      openCount: number;
      dueSoonFullDueSatang: number;
      dueSoonCount: number;
      overdueFullDueSatang: number;
      overdueCount: number;
      pendingFullDueSatang: number;
      pendingCount: number;
      needsReviewCount: number;
    };
    bills: StatementDto[];
  } {
    const bills = [...this.statements.values()]
      .filter((statement) => statement.settlementState !== 'settled')
      .map((statement) => this.statementDto(statement))
      .sort((left, right) => {
        const rank = bucketRank[left.dueBucket] - bucketRank[right.dueBucket];
        if (rank !== 0) return rank;
        if (left.dueDate !== right.dueDate) return left.dueDate < right.dueDate ? -1 : 1;
        return left.id < right.id ? -1 : left.id > right.id ? 1 : 0;
      });
    const open = [...this.statements.values()].filter((statement) => countsAsOpen(statement.settlementState));
    const pending = [...this.statements.values()].filter(
      (statement) => statement.settlementState === 'payment_pending',
    );
    const dueSoon = open.filter((statement) => dueBucket(statement.dueDate, this.today) === 'due_soon');
    const overdue = open.filter((statement) => dueBucket(statement.dueDate, this.today) === 'overdue');
    return {
      demo: {
        today: this.today,
        timeZone: 'Asia/Bangkok',
        noRealMoney: true,
        currency: 'THB',
        amountUnit: 'satang',
      },
      totals: {
        openFullDueSatang: sum(open, (statement) => statement.fullDueSatang),
        openMinDueSatang: sum(open, (statement) => statement.minDueSatang),
        openCount: open.length,
        dueSoonFullDueSatang: sum(dueSoon, (statement) => statement.fullDueSatang),
        dueSoonCount: dueSoon.length,
        overdueFullDueSatang: sum(overdue, (statement) => statement.fullDueSatang),
        overdueCount: overdue.length,
        pendingFullDueSatang: sum(pending, (statement) => statement.fullDueSatang),
        pendingCount: pending.length,
        needsReviewCount: open.filter((statement) => statement.reviewState === 'needs_review').length,
      },
      bills,
    };
  }

  listCards(): Array<CardRecord & { issuerNameEn: string; issuerNameTh: string; openFullDueSatang: number; openStatementCount: number }> {
    return [...this.cards.values()]
      .map((card) => {
        const open = [...this.statements.values()].filter(
          (statement) => statement.cardId === card.id && countsAsOpen(statement.settlementState),
        );
        const issuer = this.fixture.issuers[card.issuer];
        return {
          ...card,
          issuerNameEn: issuer.nameEn,
          issuerNameTh: issuer.nameTh,
          openFullDueSatang: sum(open, (statement) => statement.fullDueSatang),
          openStatementCount: open.length,
        };
      })
      .sort((left, right) => (left.id < right.id ? -1 : 1));
  }

  getCard(id: string): {
    card: CardRecord & { issuerNameEn: string; issuerNameTh: string };
    statements: StatementDto[];
  } {
    const card = this.cards.get(id);
    if (!card) {
      throw new HttpError(404, 'not_found', 'Card not found.');
    }
    const issuer = this.fixture.issuers[card.issuer];
    return {
      card: { ...card, issuerNameEn: issuer.nameEn, issuerNameTh: issuer.nameTh },
      statements: [...this.statements.values()]
        .filter((statement) => statement.cardId === id)
        .map((statement) => this.statementDto(statement))
        .sort((left, right) => (left.dueDate < right.dueDate ? -1 : 1)),
    };
  }

  listStatements(): StatementDto[] {
    return [...this.statements.values()]
      .map((statement) => this.statementDto(statement))
      .sort((left, right) => (left.dueDate < right.dueDate ? -1 : left.dueDate > right.dueDate ? 1 : 0));
  }

  getStatement(id: string): StatementDto {
    return this.statementDto(this.requireStatement(id));
  }

  listSamples(): Array<DemoFixture['samples'][number] & { alreadyImported: boolean }> {
    return this.fixture.samples.map((sample) => ({
      ...sample,
      alreadyImported: [...this.statements.values()].some(
        (statement) => statement.fingerprint === fingerprint(sample.issuer, sample.last4, sample.periodEnd),
      ),
    }));
  }

  importSample(sampleId: string): StatementRecord {
    const sample = this.fixture.samples.find((item) => item.id === sampleId);
    if (!sample) {
      throw new HttpError(404, 'unknown_sample', 'Unknown sample statement.');
    }
    const { id: _id, ...draft } = sample;
    return this.importDraft(draft, 'sample_import');
  }

  importDraft(draft: Draft, source: 'sample_import' | 'pdf_import'): StatementRecord {
    const parsed = draftSchema.safeParse(draft);
    if (!parsed.success) {
      throw new HttpError(400, 'validation_error', 'Statement draft is invalid.', zodDetails(parsed.error));
    }
    const value = parsed.data;
    const fp = fingerprint(value.issuer, value.last4, value.periodEnd);
    const existing = [...this.statements.values()].find((statement) => statement.fingerprint === fp);
    if (existing) {
      throw new HttpError(
        409,
        'duplicate_statement',
        'A statement for this card and period is already in the ledger.',
        { existingStatementId: existing.id },
      );
    }
    const card = this.upsertCard(value);
    const statement: StatementRecord = {
      id: `stmt_import_${this.importSeq}`,
      cardId: card.id,
      periodStart: value.periodStart,
      periodEnd: value.periodEnd,
      statementDate: value.statementDate,
      dueDate: value.dueDate,
      fullDueSatang: value.fullDueSatang,
      minDueSatang: value.minDueSatang,
      currency: 'THB',
      reviewState: 'needs_review',
      settlementState: 'open',
      source,
      fingerprint: fp,
    };
    this.importSeq += 1;
    this.statements.set(statement.id, statement);
    return statement;
  }

  patchStatement(
    id: string,
    patch: {
      fullDueSatang?: number;
      minDueSatang?: number;
      dueDate?: string;
      statementDate?: string;
    },
  ): StatementRecord {
    const statement = this.requireStatement(id);
    if (statement.reviewState !== 'needs_review') {
      throw new HttpError(409, 'not_editable', 'Confirmed statements cannot be edited.');
    }
    const card = this.requireCard(statement.cardId);
    const merged = {
      issuer: card.issuer,
      last4: card.last4,
      network: card.network,
      periodStart: statement.periodStart,
      periodEnd: statement.periodEnd,
      statementDate: patch.statementDate ?? statement.statementDate,
      dueDate: patch.dueDate ?? statement.dueDate,
      fullDueSatang: patch.fullDueSatang ?? statement.fullDueSatang,
      minDueSatang: patch.minDueSatang ?? statement.minDueSatang,
    };
    const parsed = draftSchema.safeParse(merged);
    if (!parsed.success) {
      throw new HttpError(400, 'validation_error', 'Statement update is invalid.', zodDetails(parsed.error));
    }
    statement.statementDate = parsed.data.statementDate;
    statement.dueDate = parsed.data.dueDate;
    statement.fullDueSatang = parsed.data.fullDueSatang;
    statement.minDueSatang = parsed.data.minDueSatang;
    return statement;
  }

  confirmStatement(id: string): StatementRecord {
    const statement = this.requireStatement(id);
    statement.reviewState = 'confirmed';
    return statement;
  }

  beginIdempotency(key: string, hash: string): IdempotencyDecision {
    const existing = this.idempotency.get(key);
    if (!existing) {
      this.idempotency.set(key, { state: 'in_progress', hash });
      return { type: 'start' };
    }
    if (existing.state === 'in_progress') {
      return { type: 'in_progress' };
    }
    if (existing.hash !== hash) {
      return { type: 'conflict' };
    }
    return { type: 'replay', statusCode: existing.statusCode, body: existing.body };
  }

  completeIdempotency(key: string, statusCode: number, body: unknown): void {
    const existing = this.idempotency.get(key);
    if (!existing) {
      throw new Error(`Missing idempotency record ${key}`);
    }
    this.idempotency.set(key, { state: 'done', hash: existing.hash, statusCode, body });
  }

  deleteIdempotency(key: string): void {
    this.idempotency.delete(key);
  }

  createPayment(statementIds: readonly string[], idempotencyKey: string): PaymentRecord {
    if (new Set(statementIds).size !== statementIds.length) {
      throw new HttpError(400, 'validation_error', 'Select each statement only once.', [
        { path: 'statementIds', code: 'duplicate_statement_id', message: 'Duplicate statement id.' },
      ]);
    }
    const ordered = [...statementIds].sort();
    const details: Array<{ statementId: string; reason: string }> = [];
    const selected: StatementRecord[] = [];
    for (const id of ordered) {
      const statement = this.statements.get(id);
      if (!statement) {
        details.push({ statementId: id, reason: 'not_found' });
        continue;
      }
      const reason = payableReason(statement);
      if (reason) {
        details.push({ statementId: id, reason });
      } else {
        selected.push(statement);
      }
    }
    if (details.length > 0) {
      throw new HttpError(409, 'statement_not_payable', 'One or more statements cannot be paid.', details);
    }
    const items: PaymentItem[] = selected.map((statement) => {
      const card = this.requireCard(statement.cardId);
      const issuer = this.fixture.issuers[card.issuer];
      const status = issuer.outcome;
      if (status === 'succeeded') statement.settlementState = 'settled';
      else if (status === 'failed') statement.settlementState = 'payment_failed';
      else statement.settlementState = 'payment_pending';
      return {
        statementId: statement.id,
        issuer: card.issuer,
        last4: card.last4,
        amountSatang: statement.fullDueSatang,
        status,
        simulatorCode: issuer.outcomeCode,
      };
    });
    const payment: PaymentRecord = {
      id: `pay_${this.paymentSeq}`,
      idempotencyKey,
      createdAt: formatBangkokIso(this.clock()),
      autoRetry: false,
      batchStatus: batchStatus(items.map((item) => item.status)),
      items,
    };
    this.paymentSeq += 1;
    this.payments.set(payment.id, payment);
    return payment;
  }

  listPayments(): PaymentDto[] {
    return [...this.payments.values()]
      .map((payment) => this.paymentDto(payment))
      .sort((left, right) => (left.createdAt < right.createdAt ? 1 : left.createdAt > right.createdAt ? -1 : 0));
  }

  getPayment(id: string): PaymentDto {
    const payment = this.payments.get(id);
    if (!payment) {
      throw new HttpError(404, 'not_found', 'Payment not found.');
    }
    return this.paymentDto(payment);
  }

  statementDto(statement: StatementRecord): StatementDto {
    const card = this.requireCard(statement.cardId);
    const issuer = this.fixture.issuers[card.issuer];
    return {
      id: statement.id,
      cardId: card.id,
      issuer: card.issuer,
      issuerNameEn: issuer.nameEn,
      issuerNameTh: issuer.nameTh,
      network: card.network,
      last4: card.last4,
      periodStart: statement.periodStart,
      periodEnd: statement.periodEnd,
      statementDate: statement.statementDate,
      dueDate: statement.dueDate,
      fullDueSatang: statement.fullDueSatang,
      minDueSatang: statement.minDueSatang,
      currency: 'THB',
      reviewState: statement.reviewState,
      settlementState: statement.settlementState,
      source: statement.source,
      dueBucket: dueBucket(statement.dueDate, this.today, this.fixture.dueSoonDays),
    };
  }

  paymentDto(payment: PaymentRecord): PaymentDto {
    return {
      id: payment.id,
      idempotencyKey: payment.idempotencyKey,
      createdAt: payment.createdAt,
      autoRetry: false,
      batchStatus: payment.batchStatus,
      items: payment.items.map((item) => ({
        ...item,
        outcomeMessage: outcomeMessage(item.status),
      })),
    };
  }

  private requireStatement(id: string): StatementRecord {
    const statement = this.statements.get(id);
    if (!statement) {
      throw new HttpError(404, 'not_found', 'Statement not found.');
    }
    return statement;
  }

  private requireCard(id: string): CardRecord {
    const card = this.cards.get(id);
    if (!card) {
      throw new Error(`Missing card ${id}`);
    }
    return card;
  }

  private upsertCard(draft: Draft): CardRecord {
    const existing = [...this.cards.values()].find(
      (card) => card.issuer === draft.issuer && card.last4 === draft.last4,
    );
    if (existing) {
      return existing;
    }
    const card: CardRecord = {
      id: `card_${draft.issuer}`,
      issuer: draft.issuer,
      network: draft.network,
      last4: draft.last4,
    };
    this.cards.set(card.id, card);
    return card;
  }
}

function sum<T>(items: readonly T[], pick: (item: T) => number): number {
  return items.reduce((total, item) => total + pick(item), 0);
}

export function createStore(options?: { today?: string; clock?: Clock; fixture?: DemoFixture }): MemoryStore {
  const fixture = options?.fixture ?? loadFixture();
  return new MemoryStore(fixture, options?.today ?? fixture.demoToday, options?.clock ?? (() => new Date()));
}

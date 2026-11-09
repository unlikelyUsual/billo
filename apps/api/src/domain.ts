import { createHash } from 'node:crypto';
import { z } from 'zod';

import { HttpError } from './errors';

export const ISSUER_IDS = ['kbank', 'scb', 'bbl', 'krungsri', 'ktc', 'ttb'] as const;
export type IssuerId = (typeof ISSUER_IDS)[number];
export type Network = 'visa' | 'mastercard';
export type Outcome = 'succeeded' | 'failed' | 'pending';
export type ReviewState = 'needs_review' | 'confirmed';
export type SettlementState = 'open' | 'payment_pending' | 'settled' | 'payment_failed';
export type StatementSource = 'seed' | 'sample_import' | 'pdf_import';
export type BatchStatus = 'succeeded' | 'failed' | 'partial' | 'action_required';
export type DueBucket = 'overdue' | 'due_soon' | 'later';

export const DUE_SOON_DAYS = 7;
export const MAX_SATANG = 10_000_000_000;
export const DEMO_TIME_ZONE = 'Asia/Bangkok';

const FORBIDDEN_KEYS = new Set([
  'pan',
  'cvv',
  'cvc',
  'cvv2',
  'cardnumber',
  'cardnum',
  'primaryaccountnumber',
  'password',
  'passwd',
  'pin',
  'otp',
  'tokens',
  'token',
  'accesstoken',
  'refreshtoken',
  'mailbox',
  'gmail',
  'imap',
  'credential',
  'credentials',
]);

export function normalizeKey(key: string): string {
  return key.toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function looksLikePan(value: string): boolean {
  const compact = value.replace(/[\s-]/g, '');
  if (/^\d{13,19}$/.test(compact)) {
    return true;
  }
  return /(?:^|\D)\d{13,19}(?!\d)/.test(compact);
}

/** True when raw JSON contains a non-integer number token outside a string. */
export function jsonHasNonIntegerNumber(text: string): boolean {
  let index = 0;
  while (index < text.length) {
    const char = text.charAt(index);
    if (char === '"') {
      index += 1;
      while (index < text.length) {
        if (text.charAt(index) === '\\') {
          index += 2;
          continue;
        }
        if (text.charAt(index) === '"') {
          index += 1;
          break;
        }
        index += 1;
      }
      continue;
    }
    if (char === '-' || (char >= '0' && char <= '9')) {
      let cursor = index;
      if (text.charAt(cursor) === '-') {
        cursor += 1;
      }
      while (cursor < text.length && text.charAt(cursor) >= '0' && text.charAt(cursor) <= '9') {
        cursor += 1;
      }
      const next = text.charAt(cursor);
      if (next === '.' || next === 'e' || next === 'E') {
        return true;
      }
      index = cursor;
      continue;
    }
    index += 1;
  }
  return false;
}

export function assertNoSecrets(value: unknown): void {
  walkSecrets(value);
}

function walkSecrets(value: unknown): void {
  if (Array.isArray(value)) {
    for (const item of value) {
      walkSecrets(item);
    }
    return;
  }
  if (!value || typeof value !== 'object' || Buffer.isBuffer(value)) {
    return;
  }
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    if (FORBIDDEN_KEYS.has(normalizeKey(key))) {
      throw new HttpError(
        400,
        'secret_field_rejected',
        'Raw card numbers, CVV, passwords, and mailbox credentials are not accepted.',
      );
    }
    if (typeof item === 'string' && looksLikePan(item)) {
      throw new HttpError(
        400,
        'secret_field_rejected',
        'A value looks like a full card number. Send the last 4 digits only.',
      );
    }
    walkSecrets(item);
  }
}

export function isRealDate(iso: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match) {
    return false;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) {
    return false;
  }
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

export function addDays(iso: string, days: number): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match?.[1] || !match[2] || !match[3]) {
    throw new Error(`Expected a civil date, received ${iso}`);
  }
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]) + days));
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function dueBucket(due: string, today: string, soonDays = DUE_SOON_DAYS): DueBucket {
  if (due < today) {
    return 'overdue';
  }
  if (due <= addDays(today, soonDays)) {
    return 'due_soon';
  }
  return 'later';
}

export function formatBangkokIso(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: DEMO_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const pick = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((part) => part.type === type)?.value ?? '00';
  const hour = pick('hour') === '24' ? '00' : pick('hour');
  return `${pick('year')}-${pick('month')}-${pick('day')}T${hour}:${pick('minute')}:${pick('second')}+07:00`;
}

export function countsAsOpen(state: SettlementState): boolean {
  return state === 'open' || state === 'payment_failed';
}

export function payableReason(statement: {
  reviewState: ReviewState;
  settlementState: SettlementState;
}): string | null {
  if (statement.reviewState !== 'confirmed') {
    return 'needs_review';
  }
  if (statement.settlementState === 'payment_pending') {
    return 'payment_pending';
  }
  if (statement.settlementState === 'settled') {
    return 'settled';
  }
  if (statement.settlementState === 'open' || statement.settlementState === 'payment_failed') {
    return null;
  }
  return 'not_payable';
}

export function batchStatus(outcomes: readonly Outcome[]): BatchStatus {
  if (outcomes.length === 0) {
    throw new Error('A payment needs at least one item.');
  }
  if (outcomes.some((item) => item === 'pending')) {
    return 'action_required';
  }
  const unique = new Set(outcomes);
  if (unique.size === 1 && unique.has('succeeded')) {
    return 'succeeded';
  }
  if (unique.size === 1 && unique.has('failed')) {
    return 'failed';
  }
  return 'partial';
}

export function outcomeMessage(outcome: Outcome): string {
  if (outcome === 'succeeded') {
    return 'Marked settled in the demo ledger. No money moved.';
  }
  if (outcome === 'failed') {
    return 'The demo issuer declined this bill. No money moved.';
  }
  return 'Outcome uncertain. This demo will not retry the payment.';
}

export function fingerprint(issuer: string, last4: string, periodEnd: string): string {
  return `${issuer}|${last4}|${periodEnd}`;
}

export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value) ?? 'null';
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(',')}]`;
  }
  const entries = Object.entries(value as Record<string, unknown>).sort(([left], [right]) =>
    left < right ? -1 : left > right ? 1 : 0,
  );
  return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${stableStringify(item)}`).join(',')}}`;
}

export function hashBody(value: unknown): string {
  return createHash('sha256').update(stableStringify(value)).digest('hex');
}

const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine(isRealDate, 'Invalid calendar date');

export const satangSchema = z.number().int().nonnegative().max(MAX_SATANG);

export const draftSchema = z
  .object({
    issuer: z.enum(ISSUER_IDS),
    last4: z.string().regex(/^\d{4}$/),
    network: z.enum(['visa', 'mastercard']),
    periodStart: isoDate,
    periodEnd: isoDate,
    statementDate: isoDate,
    dueDate: isoDate,
    fullDueSatang: satangSchema,
    minDueSatang: satangSchema,
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.minDueSatang > value.fullDueSatang) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['minDueSatang'],
        message: 'Minimum due cannot exceed the full amount due.',
        params: { code: 'min_exceeds_full' },
      });
    }
    if (value.periodStart > value.periodEnd) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['periodEnd'],
        message: 'Period end is before period start.',
        params: { code: 'period_order' },
      });
    }
    if (value.statementDate > value.dueDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['dueDate'],
        message: 'Due date is before the statement date.',
        params: { code: 'due_before_statement' },
      });
    }
  });

export type Draft = z.infer<typeof draftSchema>;

export const patchSchema = z
  .object({
    fullDueSatang: satangSchema.optional(),
    minDueSatang: satangSchema.optional(),
    dueDate: isoDate.optional(),
    statementDate: isoDate.optional(),
  })
  .strict()
  .refine((value) => Object.values(value).some((item) => item !== undefined), {
    message: 'Provide at least one field to update.',
    path: [],
  });

export const paymentSchema = z
  .object({
    statementIds: z.array(z.string().min(1).max(80)).min(1).max(10),
  })
  .strict();

export const sampleRequestSchema = z
  .object({
    sampleId: z.string().min(1).max(80),
  })
  .strict();

export const pdfFixtureSchema = z
  .object({
    fixture: z.enum(['verified-sample', 'unsupported-letter']),
  })
  .strict();

export function zodDetails(error: z.ZodError): Array<{ path: string; code: string; message: string }> {
  return error.issues.map((issue) => {
    const params = issue as { params?: { code?: unknown } };
    const custom = params.params?.code;
    return {
      path: issue.path.join('.') || '$',
      code: typeof custom === 'string' ? custom : issue.code,
      message: issue.message,
    };
  });
}

import fs from 'node:fs';
import path from 'node:path';
import { z } from 'zod';

import { ISSUER_IDS } from './domain';

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const satang = z.number().int().nonnegative();

const issuerSchema = z
  .object({
    nameEn: z.string().min(1),
    nameTh: z.string().min(1),
    outcome: z.enum(['succeeded', 'failed', 'pending']),
    outcomeCode: z.string().min(1),
  })
  .strict();

const cardSchema = z
  .object({
    id: z.string().min(1),
    issuer: z.enum(ISSUER_IDS),
    network: z.enum(['visa', 'mastercard']),
    last4: z.string().regex(/^\d{4}$/),
  })
  .strict();

const statementSchema = z
  .object({
    id: z.string().min(1),
    cardId: z.string().min(1),
    periodStart: isoDate,
    periodEnd: isoDate,
    statementDate: isoDate,
    dueDate: isoDate,
    fullDueSatang: satang,
    minDueSatang: satang,
    currency: z.literal('THB'),
    reviewState: z.enum(['needs_review', 'confirmed']),
    settlementState: z.enum(['open', 'payment_pending', 'settled', 'payment_failed']),
    source: z.literal('seed'),
  })
  .strict();

const sampleSchema = z
  .object({
    id: z.string().min(1),
    issuer: z.enum(ISSUER_IDS),
    last4: z.string().regex(/^\d{4}$/),
    network: z.enum(['visa', 'mastercard']),
    periodStart: isoDate,
    periodEnd: isoDate,
    statementDate: isoDate,
    dueDate: isoDate,
    fullDueSatang: satang,
    minDueSatang: satang,
  })
  .strict();

const paymentSchema = z
  .object({
    id: z.string().min(1),
    idempotencyKey: z.string().min(1),
    createdAt: z.string().min(1),
    items: z
      .array(
        z
          .object({
            statementId: z.string().min(1),
            status: z.enum(['succeeded', 'failed', 'pending']),
            simulatorCode: z.string().min(1),
            amountSatang: satang,
          })
          .strict(),
      )
      .min(1),
  })
  .strict();

export const fixtureSchema = z
  .object({
    demoToday: isoDate,
    timeZone: z.literal('Asia/Bangkok'),
    dueSoonDays: z.literal(7),
    issuers: z
      .object({
        kbank: issuerSchema,
        scb: issuerSchema,
        bbl: issuerSchema,
        krungsri: issuerSchema,
        ktc: issuerSchema,
        ttb: issuerSchema,
      })
      .strict(),
    cards: z.array(cardSchema).min(1),
    statements: z.array(statementSchema).min(1),
    samples: z.array(sampleSchema).min(1),
    payments: z.array(paymentSchema),
  })
  .strict();

export type DemoFixture = z.infer<typeof fixtureSchema>;

export function defaultFixturePath(): string {
  return path.resolve(__dirname, '../../../packages/contracts/fixtures/demo.json');
}

export function defaultFixtureDir(): string {
  return path.resolve(__dirname, '../../../packages/contracts/fixtures');
}

export function loadFixture(filePath = defaultFixturePath()): DemoFixture {
  const raw: unknown = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const parsed = fixtureSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(`Invalid demo fixture: ${parsed.error.message}`);
  }
  return parsed.data;
}

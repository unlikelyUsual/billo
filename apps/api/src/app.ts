import fs from 'node:fs';
import path from 'node:path';

import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';

import {
  assertNoSecrets,
  hashBody,
  jsonHasNonIntegerNumber,
  paymentSchema,
  pdfFixtureSchema,
  sampleRequestSchema,
  patchSchema,
  zodDetails,
} from './domain';
import { HttpError } from './errors';
import { defaultFixtureDir } from './fixture';
import { extractStatementPdf } from './pdf';
import { createStore, type Clock, type MemoryStore } from './store';

declare module 'fastify' {
  interface FastifyInstance {
    registeredRoutes: Array<{ method: string; url: string }>;
  }
}

const IDEMPOTENCY_KEY = /^[A-Za-z0-9._:-]{8,80}$/;

export type AppOptions = {
  today?: string;
  clock?: Clock;
  logger?: boolean;
  store?: MemoryStore;
};

export function buildApp(options: AppOptions = {}): FastifyInstance {
  const store = options.store ?? createStore({ today: options.today, clock: options.clock });
  const registeredRoutes: Array<{ method: string; url: string }> = [];
  const app = Fastify({
    logger: options.logger ?? false,
    bodyLimit: 2 * 1024 * 1024,
  });
  app.decorate('registeredRoutes', registeredRoutes);
  app.removeContentTypeParser('application/json');
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (_request, body, done) => {
    const text = typeof body === 'string' ? body : '';
    if (text.trim() === '') {
      done(null, {});
      return;
    }
    if (jsonHasNonIntegerNumber(text)) {
      done(new HttpError(400, 'amount_not_integer', 'Amounts must be integers in satang.'), undefined);
      return;
    }
    try {
      done(null, JSON.parse(text) as unknown);
    } catch {
      done(new HttpError(400, 'invalid_json', 'Request body is not valid JSON.'), undefined);
    }
  });
  app.addContentTypeParser('application/pdf', { parseAs: 'buffer' }, (_request, body, done) => {
    done(null, body);
  });
  app.addHook('onRequest', async (request, reply) => {
    reply.header('Access-Control-Allow-Origin', '*');
    reply.header('Access-Control-Allow-Headers', 'Content-Type, Idempotency-Key');
    reply.header('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
    reply.header('Access-Control-Expose-Headers', 'Idempotency-Replay');
    if (request.method === 'OPTIONS') {
      return reply.code(204).send();
    }
  });
  app.addHook('preHandler', async (request) => {
    const body = request.body;
    if (body && typeof body === 'object' && !Buffer.isBuffer(body)) {
      assertNoSecrets(body);
    }
  });
  app.setNotFoundHandler((request, reply) => {
    reply.code(404).send({
      error: { code: 'not_found', message: `No route ${request.method} ${request.url}` },
    });
  });
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof HttpError) {
      return reply.code(error.status).send(error.body());
    }
    const statusCode = readNumber(error, 'statusCode');
    const code = readString(error, 'code');
    if (statusCode === 413) {
      return reply.code(413).send({
        error: { code: 'payload_too_large', message: 'Request is too large.' },
      });
    }
    if (code === 'FST_ERR_CTP_INVALID_JSON' || statusCode === 400) {
      return reply.code(400).send({
        error: { code: 'invalid_json', message: 'Request body is not valid JSON.' },
      });
    }
    return reply.code(500).send({
      error: { code: 'internal_error', message: 'Unexpected error' },
    });
  });

  const route = (
    method: 'GET' | 'POST' | 'PATCH',
    url: string,
    handler: (request: FastifyRequest, reply: FastifyReply) => Promise<unknown>,
  ): void => {
    registeredRoutes.push({ method, url });
    app.route({ method, url, handler });
  };

  route('GET', '/health', async () => ({
    ok: true,
    service: 'billo-api',
    demo: true,
    timeZone: 'Asia/Bangkok',
  }));
  route('GET', '/v1/meta', async () => store.meta());
  route('GET', '/v1/home', async () => store.home());
  route('GET', '/v1/cards', async () => ({ cards: store.listCards() }));
  route('GET', '/v1/cards/:id', async (request) => store.getCard(param(request, 'id')));
  route('GET', '/v1/statements', async () => ({ statements: store.listStatements() }));
  route('GET', '/v1/statements/:id', async (request) => ({
    statement: store.getStatement(param(request, 'id')),
  }));
  route('PATCH', '/v1/statements/:id', async (request) => {
    const parsed = patchSchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      throw new HttpError(400, 'validation_error', 'Statement update is invalid.', zodDetails(parsed.error));
    }
    return { statement: store.statementDto(store.patchStatement(param(request, 'id'), parsed.data)) };
  });
  route('POST', '/v1/statements/:id/confirm', async (request) => ({
    statement: store.statementDto(store.confirmStatement(param(request, 'id'))),
  }));
  route('GET', '/v1/samples', async () => ({ samples: store.listSamples() }));
  route('POST', '/v1/imports/sample', async (request, reply) => {
    const parsed = sampleRequestSchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      throw new HttpError(400, 'validation_error', 'Sample import is invalid.', zodDetails(parsed.error));
    }
    const statement = store.importSample(parsed.data.sampleId);
    return reply.code(201).send({ statement: store.statementDto(statement) });
  });
  route('POST', '/v1/imports/pdf', async (request, reply) => {
    const bytes = await readPdfBytes(request);
    const extracted = extractStatementPdf(bytes);
    if (extracted.status === 'unavailable') {
      return reply.code(422).send({
        status: 'unavailable',
        error: {
          code: 'pdf_extraction_unavailable',
          reason: extracted.reason,
          message: extracted.message,
        },
      });
    }
    const statement = store.importDraft(extracted.draft, 'pdf_import');
    return reply.code(201).send({
      status: 'extracted',
      statement: store.statementDto(statement),
    });
  });
  route('GET', '/v1/payments', async () => ({ payments: store.listPayments() }));
  route('GET', '/v1/payments/:id', async (request) => ({ payment: store.getPayment(param(request, 'id')) }));
  route('POST', '/v1/payments', async (request, reply) =>
    handlePayment(store, request, reply),
  );
  route('POST', '/v1/payments/:id/retry', async (request) => {
    store.getPayment(param(request, 'id'));
    throw new HttpError(
      409,
      'no_auto_retry',
      'Billo does not retry payments. If an issuer result is still pending, leave it and reconcile before paying that bill again. Failed bills stay open for a new payment.',
      { autoRetry: false },
    );
  });
  route('POST', '/v1/demo/reset', async () => {
    store.reset();
    return { reset: true };
  });

  return app;
}

async function readPdfBytes(request: FastifyRequest): Promise<Buffer> {
  if (Buffer.isBuffer(request.body)) {
    return request.body;
  }
  const parsed = pdfFixtureSchema.safeParse(request.body ?? {});
  if (!parsed.success) {
    throw new HttpError(
      400,
      'validation_error',
      'Send a PDF body or a known demo fixture name.',
      zodDetails(parsed.error),
    );
  }
  const fileName =
    parsed.data.fixture === 'verified-sample' ? 'verified-sample.pdf' : 'unsupported-letter.pdf';
  return fs.readFileSync(path.join(defaultFixtureDir(), fileName));
}

async function handlePayment(
  store: MemoryStore,
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<unknown> {
  const key = readIdempotencyKey(request);
  const parsed = paymentSchema.safeParse(request.body ?? {});
  const canonical = parsed.success
    ? { statementIds: [...parsed.data.statementIds].sort() }
    : request.body ?? {};
  const decision = store.beginIdempotency(key, hashBody(canonical));
  if (decision.type === 'replay') {
    reply.header('Idempotency-Replay', 'true');
    return reply.code(decision.statusCode).send(decision.body);
  }
  if (decision.type === 'conflict') {
    throw new HttpError(
      409,
      'idempotency_conflict',
      'This Idempotency-Key was already used for a different payment request.',
    );
  }
  if (decision.type === 'in_progress') {
    throw new HttpError(409, 'idempotency_in_progress', 'This Idempotency-Key is already in progress.');
  }
  try {
    if (!parsed.success) {
      throw new HttpError(400, 'validation_error', 'Payment request is invalid.', zodDetails(parsed.error));
    }
    const payment = store.createPayment(parsed.data.statementIds, key);
    const body = { payment: store.paymentDto(payment) };
    store.completeIdempotency(key, 201, body);
    reply.header('Idempotency-Replay', 'false');
    return reply.code(201).send(body);
  } catch (error) {
    if (error instanceof HttpError && error.status < 500) {
      store.completeIdempotency(key, error.status, error.body());
    } else {
      store.deleteIdempotency(key);
    }
    throw error;
  }
}

function readIdempotencyKey(request: FastifyRequest): string {
  const header = request.headers['idempotency-key'];
  const value = Array.isArray(header) ? header[0] : header;
  if (!value) {
    throw new HttpError(400, 'idempotency_key_required', 'Send an Idempotency-Key header.');
  }
  if (!IDEMPOTENCY_KEY.test(value)) {
    throw new HttpError(
      400,
      'idempotency_key_invalid',
      'Idempotency-Key must be 8 to 80 characters of letters, numbers, dot, underscore, colon, or hyphen.',
    );
  }
  return value;
}

function param(request: FastifyRequest, name: string): string {
  const params = request.params as Record<string, unknown>;
  const value = params[name];
  if (typeof value !== 'string' || value.length === 0) {
    throw new HttpError(400, 'validation_error', `Missing ${name}.`);
  }
  return value;
}

function readNumber(error: unknown, key: string): number | undefined {
  if (!error || typeof error !== 'object' || !(key in error)) return undefined;
  const value = (error as Record<string, unknown>)[key];
  return typeof value === 'number' ? value : undefined;
}

function readString(error: unknown, key: string): string | undefined {
  if (!error || typeof error !== 'object' || !(key in error)) return undefined;
  const value = (error as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : undefined;
}
